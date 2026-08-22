//
//  HandPoseManager.swift
//  VisionChef
//
//  Captures camera frames, runs VNDetectHumanHandPoseRequest on each frame,
//  tracks up to two hands independently, and classifies each as grabbing
//  (thumb tip pinched to little-finger tip) or open (everything else).
//
//  Vision inference runs entirely on a background queue (`videoQueue`); only
//  the final @Published updates are hopped onto the main queue, so a slow
//  frame never stalls SwiftUI/SpriteKit.
//

import AVFoundation
import Vision
import Combine
import CoreGraphics
import QuartzCore

final class HandPoseManager: NSObject, ObservableObject {
    /// Alias for HumanBodyPoseManager's BodyCandidate for backward compatibility.
    typealias BodyCandidate = HumanBodyPoseManager.BodyCandidate

    // MARK: - Published state consumed by SwiftUI / SpriteKit
    // All writes are dispatched onto the main queue; safe to read from SwiftUI.

    /// Every hand currently tracked, up to `maximumHandCount`.
    @Published private(set) var hands: [HandData] = []

    /// The player's upper body in normalized Vision space, nil when nobody is
    /// tracked.
    ///
    /// Exactly one body ever appears here: the nearest. Other people in frame
    /// are never published, however much of them Vision can see.
    @Published private(set) var playerBody: BodyCandidate?

    /// Camera authorization state, surfaced so the UI can prompt the user.
    @Published private(set) var authorizationStatus: AVAuthorizationStatus = .notDetermined

    /// Dimensions of the frames Vision is actually reading, after the capture
    /// connection's rotation. Needed to undo `.resizeAspectFill` cropping when
    /// mapping to the screen — without it the overlay only lines up when the
    /// screen happens to share the camera's 4:3 aspect.
    @Published private(set) var bufferSize: CGSize = .zero

    var isHandVisible: Bool { !hands.isEmpty }

    // MARK: - Configuration
    //
    // These are `var` on purpose: hand size, camera distance and lighting all
    // shift the numbers below, so they are tuning knobs, not constants.

    /// Which camera to read frames from.
    var cameraPosition: AVCaptureDevice.Position = .front

    /// Digital zoom, as a multiple of the *widest* zoom the hardware supports.
    /// 1.0 would be "as wide as this camera goes".
    ///
    /// Pinned to 2.0, which is the conventional **1×** selfie framing: a front
    /// camera is a single ultra-wide sensor, and Apple's own Camera app gets
    /// its 1× the same way, by cropping 2× into the sensor rather than
    /// switching lens. The full-wide view is deliberately not offered — it
    /// distorts faces at the edges and puts the player further away than the
    /// grab targets are tuned for.
    ///
    /// The crop costs resolution, which is why `selectWidestFormat` picks the
    /// largest format available rather than the cheapest.
    var previewZoomFactor: CGFloat = 2.0

    /// How the feed is fitted to the screen.
    var previewGravity: AVLayerVideoGravity = .resizeAspectFill

    /// Whether to switch Center Stage off for this app.
    var disablesCenterStage = true

    /// Bounds on the capture format picked in `selectWidestFormat`.
    var minimumCaptureWidth: Int32 = 640
    var maximumCaptureWidth: Int32 = 1920

    /// How many hands to actually play with — one player, two hands.
    var maximumHandCount = 2

    /// How many hands Vision may report before the single-player filter runs.
    var handCandidateLimit = 4

    /// Whether hands are gated on the body they are attached to.
    var tracksSinglePlayer = true

    /// Run the body detector on one frame in this many, reusing the last
    /// result in between.
    var bodyPoseFrameInterval: Int {
        get { bodyPoseManager.bodyPoseFrameInterval }
        set { bodyPoseManager.bodyPoseFrameInterval = newValue }
    }

    /// How far a hand's own wrist may sit from a body's wrist and still count
    /// as that body's, as a multiple of that body's shoulder span.
    var wristMatchTolerance: CGFloat {
        get { bodyPoseManager.wristMatchTolerance }
        set { bodyPoseManager.wristMatchTolerance = newValue }
    }

    /// Minimum Vision joint confidence to trust a point.
    var jointConfidenceThreshold: Float = 0.25 {
        didSet { bodyPoseManager.jointConfidenceThreshold = jointConfidenceThreshold }
    }

    /// Grabbing is a **pinch**: thumb tip and index-finger tip brought together.
    var pinchCloseRatio: CGFloat = 0.3
    var pinchOpenRatio: CGFloat = 0.5

    /// Rotation used when running on a Mac.
    var macCameraRotationAngle: CGFloat = 90

    /// Exponential smoothing applied to each cursor (0 = frozen, 1 = raw).
    var cursorSmoothing: CGFloat = 0.35

    /// How far (in normalized units) a hand may travel between frames and still
    /// be considered the same hand.
    var handMatchRadius: CGFloat = 0.45

    /// How long a hand's trajectory survives after Vision stops reporting it.
    var handGracePeriod: TimeInterval = 0.35

    // MARK: - AVFoundation / Vision plumbing

    /// Shared with `CameraPreviewView` so the AR passthrough layer renders the
    /// same feed Vision reads — iOS won't run two sessions on one camera.
    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.visionchef.camera.session")
    private let videoQueue = DispatchQueue(label: "com.visionchef.camera.video")
    private let handPoseRequest = VNDetectHumanHandPoseRequest()
    private let bodyPoseManager = HumanBodyPoseManager()
    private var isConfigured = false

    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservers: [NSKeyValueObservation] = []

    // MARK: - Per-hand tracking (accessed only from videoQueue)

    /// videoQueue-local record of a hand between frames.
    private struct TrackedHand {
        let id: Int
        var smoothed: CGPoint
        var isOpen: Bool
        /// Last time Vision actually reported this hand; drives the grace period.
        var lastSeen: TimeInterval
    }

    private var tracked: [TrackedHand] = []
    private var nextHandID = 0
    private var lastMeasuredBufferSize: CGSize = .zero

    /// videoQueue-local copy of what was last published, so an unchanged body
    /// doesn't hop onto the main queue every frame.
    private var lastPublishedBody: BodyCandidate?

    private let cameraManager = CameraManager.shared

    override init() {
        super.init()
        self.authorizationStatus = cameraManager.authorizationStatus
    }

    // MARK: - Public control

    /// Requests camera permission (if needed) and starts the capture session.
    /// Safe to call multiple times. Call from the main thread (e.g. `.onAppear`).
    func start() {
        handPoseRequest.maximumHandCount = handCandidateLimit

        cameraManager.requestCameraPermission { [weak self] granted in
            guard let self else { return }
            self.authorizationStatus = self.cameraManager.authorizationStatus
            if granted {
                self.configureSessionIfNeeded()
                self.beginRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async { [captureSession] in
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }

    // MARK: - Coordinate mapping

    /// A hand's cursor in view space (**origin top-left, y-down**).
    ///
    /// SpriteKit scenes use the opposite (bottom-left, y-up) convention, so
    /// `GameScene` must run this through `convertPoint(fromView:)` rather
    /// than assigning the result to a node position directly.
    func cursor(for hand: HandData, in size: CGSize) -> CGPoint {
        Self.viewPoint(fromNormalized: hand.cursorPosition, viewSize: size,
                       bufferSize: bufferSize, gravity: previewGravity)
    }

    /// A hand's skeleton mapped into view space, one chain per finger.
    func jointChains(for hand: HandData, in size: CGSize) -> [[CGPoint]] {
        hand.skeleton.map { chain in
            chain.map {
                Self.viewPoint(fromNormalized: $0, viewSize: size,
                               bufferSize: bufferSize, gravity: previewGravity)
            }
        }
    }

    /// The player's upper body in view space. Runs through the same mapping as
    /// the hands, so the two can never disagree about where the player is.
    func playerBody(in size: CGSize) -> BodyCandidate? {
        playerBody?.mapped {
            Self.viewPoint(fromNormalized: $0, viewSize: size,
                           bufferSize: bufferSize, gravity: previewGravity)
        }
    }

    /// The player's body as bone chains in view space, one chain per bone.
    func bodyChains(in size: CGSize) -> [[CGPoint]] {
        playerBody(in: size)?.chains ?? []
    }

    /// Every joint of a hand in view space, as a flat list.
    func jointPoints(for hand: HandData, in size: CGSize) -> [CGPoint] {
        hand.recognizedJoints.map {
            Self.viewPoint(fromNormalized: $0, viewSize: size,
                           bufferSize: bufferSize, gravity: previewGravity)
        }
    }

    /// Maps a normalized Vision point (origin bottom-left) into view space
    /// (origin top-left), reproducing what the preview layer's `gravity` does
    /// to the image: scale the frame to cover (`.resizeAspectFill`) or to fit
    /// inside (`.resizeAspect`) the view, centre it, and let any overflow hang
    /// off the edges.
    ///
    /// Skipping that crop is what pulled the skeleton off the hand on device —
    /// it costs up to ~123pt of horizontal error on a 19.5:9 iPhone, and
    /// exactly 0 on a 4:3 iPad, which is why it looked fine in some places.
    ///
    /// No horizontal flip here: the capture connection is mirrored at source
    /// (see `configureSessionIfNeeded`), so Vision already sees the same
    /// left-right arrangement the player does.
    static func viewPoint(
        fromNormalized normalized: CGPoint,
        viewSize: CGSize,
        bufferSize: CGSize,
        gravity: AVLayerVideoGravity = .resizeAspectFill
    ) -> CGPoint {
        let flipped = CGPoint(x: normalized.x, y: 1 - normalized.y)

        guard viewSize.width > 0, viewSize.height > 0,
              bufferSize.width > 0, bufferSize.height > 0,
              gravity != .resize else {
            // No frame measured yet (or an outright stretch was asked for) —
            // a plain stretch is the best mapping available.
            return CGPoint(x: flipped.x * viewSize.width, y: flipped.y * viewSize.height)
        }

        let widthScale = viewSize.width / bufferSize.width
        let heightScale = viewSize.height / bufferSize.height
        let scale = gravity == .resizeAspect
            ? min(widthScale, heightScale)   // fit: whole frame, letterboxed
            : max(widthScale, heightScale)   // fill: covers the view, cropped
        let displayed = CGSize(width: bufferSize.width * scale, height: bufferSize.height * scale)
        let origin = CGPoint(
            // Negative when filling (that edge is cropped off-screen),
            // positive when fitting (that edge is a letterbox bar).
            x: (viewSize.width - displayed.width) / 2,
            y: (viewSize.height - displayed.height) / 2
        )
        return CGPoint(
            x: origin.x + flipped.x * displayed.width,
            y: origin.y + flipped.y * displayed.height
        )
    }

    // MARK: - Session configuration

    private func configureSessionIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        // Read the tuning knobs here, on the main thread, so the session queue
        // never touches them concurrently with a caller changing them.
        let position = cameraPosition
        let zoom = previewZoomFactor
        let widthRange = minimumCaptureWidth...maximumCaptureWidth
        let turnOffCenterStage = disablesCenterStage

        sessionQueue.async { [weak self] in
            guard let self else { return }

            // Before anything else: Center Stage restricts which formats are
            // selectable *and* how far out `videoZoomFactor` may go, so turning
            // it off first is what lets the two calls below reach the real
            // limits of the hardware.
            if turnOffCenterStage { CameraManager.disableCenterStage() }

            self.captureSession.beginConfiguration()

            // This is a video-only session (no audio input), so it must not
            // touch the app's shared audio session. Left at its default (true),
            // AVCaptureSession reconfigures that session on start and tears it
            // down on stop — which is why quitting the game killed *all* audio,
            // sound effects included. Turning it off leaves AudioManager's
            // `.ambient` session alone for the whole app lifetime.
            self.captureSession.automaticallyConfiguresApplicationAudioSession = false

            // Fallback only. `selectWidestFormat` below overrides this with a
            // hand-picked format (which flips the preset to `.inputPriority`);
            // the preset matters just for devices where no format qualifies.
            self.captureSession.sessionPreset = .hd1280x720

            guard
                let device = CameraManager.widestCamera(at: position),
                let input = try? AVCaptureDeviceInput(device: device),
                self.captureSession.canAddInput(input)
            else {
                self.captureSession.commitConfiguration()
                return
            }
            self.captureSession.addInput(input)

            // Widen the *capture* itself, before anything gets cropped for the
            // screen. A preset asks only for a resolution, and AVFoundation is
            // free to satisfy it with a narrow, cropped-in format.
            CameraManager.selectWidestFormat(on: device, zoom: zoom, widthRange: widthRange)

            self.videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)

            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
            }

            if let connection = self.videoOutput.connection(with: .video),
               connection.isVideoMirroringSupported {
                // Mirror at the source so Vision and the on-screen preview
                // share one left-right arrangement.
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }

            self.captureSession.commitConfiguration()

            DispatchQueue.main.async {
                self.startTrackingRotation(for: device)
            }
        }
    }

    // MARK: - Rotation Tracking

    /// True when the app is running on a Mac rather than an iPhone/iPad.
    ///
    /// A Mac has no device orientation to follow, so the rotation coordinator
    /// has nothing meaningful to report and a fixed angle is used instead.
    private var runsOnMac: Bool {
        ProcessInfo.processInfo.isiOSAppOnMac || ProcessInfo.processInfo.isMacCatalystApp
    }

    private func startTrackingRotation(for device: AVCaptureDevice) {
        guard !runsOnMac else {
            applyRotationAngle(macCameraRotationAngle)
            return
        }

        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotationCoordinator = coordinator
        applyRotation(from: coordinator)

        rotationObservers = [
            coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { [weak self] coordinator, _ in
                self?.applyRotation(from: coordinator)
            },
            coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] coordinator, _ in
                self?.applyRotation(from: coordinator)
            }
        ]
    }

    private func applyRotation(from coordinator: AVCaptureDevice.RotationCoordinator) {
        // Deliberately the *preview* angle on both connections, not the
        // capture angle on the video output. The two differ whenever the UI
        // can't rotate with the device, and any disagreement between them
        // would rotate Vision's frame away from what's on screen.
        applyRotationAngle(coordinator.videoRotationAngleForHorizonLevelPreview)
    }

    /// Applies one angle to *both* connections, so Vision's frame and the
    /// on-screen image can never disagree about which way is up.
    ///
    /// All-or-nothing on purpose: rotating only the connection that happens to
    /// accept the angle is what leaves the skeleton lagging behind a rotated
    /// camera image.
    private func applyRotationAngle(_ angle: CGFloat) {
        let previewConnection = previewLayer?.connection
        let outputConnection = videoOutput.connection(with: .video)

        let acceptedEverywhere = [previewConnection, outputConnection]
            .compactMap { $0 }
            .allSatisfy { $0.isVideoRotationAngleSupported(angle) }
        guard acceptedEverywhere else {
            #if DEBUG
            print("[HandPoseManager] rotation \(angle)° rejected by the capture connection; feed left as-is.")
            #endif
            return
        }

        previewConnection?.videoRotationAngle = angle

        sessionQueue.async { [weak self] in
            self?.videoOutput.connection(with: .video)?.videoRotationAngle = angle
        }
    }

    /// Handed over by `CameraPreviewView` so rotation can be driven from a
    /// single coordinator that knows about both the feed and what's on screen.
    func attach(previewLayer layer: AVCaptureVideoPreviewLayer) {
        previewLayer = layer
        if let device = (captureSession.inputs.first as? AVCaptureDeviceInput)?.device {
            startTrackingRotation(for: device)
        }
    }

    private func beginRunning() {
        sessionQueue.async { [captureSession] in
            if !captureSession.isRunning {
                captureSession.startRunning()
            }
        }
    }

    // MARK: - Frame processing (runs on videoQueue, off the main thread)

    private func process(pixelBuffer: CVPixelBuffer) {
        // Dimensions come from the delivered buffer, so they already account
        // for whatever rotation the connection is applying.
        let measured = CGSize(
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer)
        )
        
        if measured != lastMeasuredBufferSize {
            lastMeasuredBufferSize = measured
            DispatchQueue.main.async { self.bufferSize = measured }
        }

        // One handler for whatever runs this frame: the image is decoded once.
        let runsBodyPose = bodyPoseManager.shouldRunBodyPose(tracksSinglePlayer: tracksSinglePlayer)

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        do {
            try handler.perform(runsBodyPose ? [handPoseRequest, bodyPoseManager.bodyPoseRequest]
                                             : [handPoseRequest])
        } catch {
            publishNoHands()
            return
        }

        // Everyone else in the room is ignored from here on. Resolved before
        // the hand guards below, so the skeleton keeps up with the player even
        // in the frames where their hands are down or out of shot — otherwise
        // the last body drawn would stay frozen on screen.
        if runsBodyPose {
            _ = bodyPoseManager.processObservations(bodyPoseManager.bodyPoseRequest.results)
        }
        let bodies = tracksSinglePlayer ? bodyPoseManager.lastBodies : []

        // Publish the nearest body and only that one, so what is drawn is
        // always exactly who the game is listening to.
        let player = bodyPoseManager.resolvePlayer(from: bodies)
        if player != lastPublishedBody {
            lastPublishedBody = player
            DispatchQueue.main.async { self.playerBody = player }
        }
        
        // MARK - Classifying Hand and Body

        let observations = handPoseRequest.results ?? []
        guard !observations.isEmpty else {
            publishNoHands()
            return
        }

        let now = CACurrentMediaTime()
        let classifications = observations.compactMap {
            try? Self.classify(
                observation: $0,
                jointConfidenceThreshold: jointConfidenceThreshold
            )
        }
        guard !classifications.isEmpty else {
            publishNoHands()
            return
        }

        // Set from the Settings sheet (SettingsView). Read straight from
        // UserDefaults rather than @AppStorage — this runs on videoQueue, off
        // the main thread, once per frame.
        let oneHandPreference: HandSide? = UserDefaults.standard.bool(forKey: "oneHandModeEnabled")
            ? HandSide(rawValue: UserDefaults.standard.string(forKey: "preferredHand") ?? "") ?? .right
            : nil
        let handLimit = oneHandPreference != nil ? 1 : maximumHandCount

        // No body, no hands. A hand is only the player's if it can be tied to
        // a visible shoulder, so a torso out of frame means nothing is tracked
        // — the same rule the seat check enforces before the game even starts.
        let keep = HumanBodyPoseManager.playerHandIndices(
            handWrists: classifications.map(\.wrist),
            bodies: bodies,
            wristTolerance: wristMatchTolerance,
            limit: handLimit,
            requiredHand: oneHandPreference
        ) ?? []

        let hands = matchToTrackedHands(keep.map { classifications[$0] }, now: now)
        DispatchQueue.main.async { self.hands = hands }
    }

    /// Result of classifying a single Vision hand observation.
    private struct Classification {
        let location: CGPoint // normalized, Vision space — palm centre
        /// The hand's own wrist joint. Matched against the *body* detector's
        /// wrists to work out whose arm this hand is on.
        let wrist: CGPoint
        /// Wrist → knuckles, normalized. Doubles as a distance-from-camera
        /// cue: the same hand twice as far away measures half as long.
        let palmLength: CGFloat
        /// Thumb-tip to index-tip gap, in palm lengths. Nil when either tip
        /// was missing this frame — the hand is then treated as open, since a
        /// grab has to be seen to count.
        let pinchRatio: CGFloat?
        let skeleton: [[CGPoint]]
    }

    /// Joint chains used both for the skeleton overlay and for the palm
    /// measurements below — wrist first, fingertip last.
    private static let fingerChains: [[VNHumanHandPoseObservation.JointName]] = [
        [.wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip],
        [.wrist, .indexMCP, .indexPIP, .indexDIP, .indexTip],
        [.wrist, .middleMCP, .middlePIP, .middleDIP, .middleTip],
        [.wrist, .ringMCP, .ringPIP, .ringDIP, .ringTip],
        [.wrist, .littleMCP, .littlePIP, .littleDIP, .littleTip]
    ]

    private static func classify(
        observation: VNHumanHandPoseObservation,
        jointConfidenceThreshold: Float
    ) throws -> Classification {
        let allPoints = try observation.recognizedPoints(.all)

        func point(_ name: VNHumanHandPoseObservation.JointName) -> CGPoint? {
            guard let joint = allPoints[name], joint.confidence >= jointConfidenceThreshold else {
                return nil
            }
            return CGPoint(x: joint.location.x, y: joint.location.y)
        }

        guard let wrist = point(.wrist) else { throw HandPoseError.noReliableWrist }

        let skeleton = fingerChains.map { $0.compactMap(point) }

        // Palm length = wrist → knuckles, the scale reference every other
        // measurement is divided by. Taking the largest available MCP keeps a
        // sane value when the middle knuckle briefly drops out.
        let knuckles: [VNHumanHandPoseObservation.JointName] = [.middleMCP, .indexMCP, .ringMCP, .littleMCP]
        let knucklePoints = knuckles.compactMap(point)
        guard let palmLength = knucklePoints.map({ wrist.distance(to: $0) }).max(), palmLength > 0 else {
            throw HandPoseError.noReliablePalm
        }

        // The grab gesture: thumb tip meeting little-finger tip. Only these two
        // joints matter — what the other three fingers are doing is ignored
        // entirely, so a fist and a flat palm both read as open.
        let pinch = pinchRatio(
            thumbTip: point(.thumbTip),
            indexTip: point(.indexTip),
            palmLength: palmLength
        )

        // Track the palm centre (wrist + knuckles) rather than including the
        // fingertips: the palm barely moves when the hand opens and closes, so
        // the cursor stays put at the exact moment the player clenches to grab.
        let palmPoints = [wrist] + knucklePoints
        let sum = palmPoints.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        let centre = CGPoint(x: sum.x / CGFloat(palmPoints.count), y: sum.y / CGFloat(palmPoints.count))

        return Classification(
            location: centre,
            wrist: wrist,
            palmLength: palmLength,
            pinchRatio: pinch,
            skeleton: skeleton
        )
    }

    // MARK: - Forwarded Static Helpers for Body Pose

    static func bodyCandidate(
        from observation: VNHumanBodyPoseObservation,
        jointConfidenceThreshold: Float
    ) -> BodyCandidate? {
        HumanBodyPoseManager.bodyCandidate(from: observation, jointConfidenceThreshold: jointConfidenceThreshold)
    }

    static func nearestBody(in bodies: [BodyCandidate]) -> Int? {
        HumanBodyPoseManager.nearestBody(in: bodies)
    }

    static func playerHandIndices(
        handWrists: [CGPoint],
        bodies: [BodyCandidate],
        wristTolerance: CGFloat,
        limit: Int,
        requiredHand: HandSide? = nil
    ) -> [Int]? {
        HumanBodyPoseManager.playerHandIndices(
            handWrists: handWrists,
            bodies: bodies,
            wristTolerance: wristTolerance,
            limit: limit,
            requiredHand: requiredHand
        )
    }

    /// The gap between thumb tip and little-finger tip, in palm lengths —
    /// small means the two are pinched together, which is the grab gesture.
    ///
    /// Nil when either tip is missing, or the palm couldn't be measured: the
    /// caller reads that as "not grabbing", so a hand whose thumb drops out of
    /// tracking opens rather than clamping shut on whatever is nearby.
    ///
    /// Extracted from `classify` so the tuning maths can be exercised without
    /// having to fabricate a `VNHumanHandPoseObservation`.
    static func pinchRatio(
        thumbTip: CGPoint?,
        indexTip: CGPoint?,
        palmLength: CGFloat
    ) -> CGFloat? {
        guard palmLength > 0, let thumbTip, let indexTip else { return nil }
        return thumbTip.distance(to: indexTip) / palmLength
    }

    private enum HandPoseError: Error {
        case noReliableWrist
        case noReliablePalm
    }

    // MARK: - Identity tracking + swipes (runs on videoQueue)

    /// Assigns each fresh observation to the tracked hand it most likely
    /// continues, so `HandData.id` stays put frame to frame.
    ///
    /// Vision hands back observations in no particular order, so without this
    /// the two hands would trade identities at random — and with them, whatever
    /// each was dragging.
    private func matchToTrackedHands(_ classifications: [Classification], now: TimeInterval) -> [HandData] {
        let assignments = Self.matchAssignments(
            newPositions: classifications.map(\.location),
            previousPositions: tracked.map(\.smoothed),
            radius: handMatchRadius
        )

        var result: [HandData] = []
        var stillTracked: [TrackedHand] = []

        for (index, classification) in classifications.enumerated() {
            var hand: TrackedHand
            if let previous = assignments[index] {
                hand = tracked[previous]
            } else {
                hand = TrackedHand(id: nextHandID, smoothed: classification.location,
                                   isOpen: false, lastSeen: now)
                nextHandID += 1
            }
            hand.lastSeen = now

            // Smooth the cursor: Vision's per-frame jitter is easily 20–30pt on
            // screen, enough to slide off an ingredient mid-grab.
            hand.smoothed = CGPoint(
                x: hand.smoothed.x + (classification.location.x - hand.smoothed.x) * cursorSmoothing,
                y: hand.smoothed.y + (classification.location.y - hand.smoothed.y) * cursorSmoothing
            )

            // Hysteresis is per hand, so one hand pinching can't flip the other.
            // A missing pinch measurement opens the hand outright rather than
            // holding the previous state — see `pinchRatio`.
            let isOpen: Bool
            if let pinch = classification.pinchRatio {
                if pinch <= pinchCloseRatio {
                    isOpen = false
                } else if pinch >= pinchOpenRatio {
                    isOpen = true
                } else {
                    isOpen = hand.isOpen
                }
            } else {
                isOpen = true
            }
            hand.isOpen = isOpen

            stillTracked.append(hand)
            result.append(HandData(
                id: hand.id,
                cursorPosition: hand.smoothed,
                isOpenHand: isOpen,
                isClosedFist: !isOpen,
                skeleton: classification.skeleton
            ))
        }

        // Hold on to hands Vision didn't report this frame. Their trajectory is
        // still live for the grace period, so a flick that blurs out halfway
        // through is still measurable when the hand reappears.
        let matched = Set(assignments.compactMap { $0 })
        for (index, previous) in tracked.enumerated()
        where !matched.contains(index) && now - previous.lastSeen <= handGracePeriod {
            stillTracked.append(previous)
        }

        tracked = stillTracked
        return result
    }

    /// For each freshly detected hand position, the index of the previously
    /// tracked hand it continues — or nil when it's a new hand.
    ///
    /// Greedy nearest-neighbour, each previous hand claimable once. This is
    /// what keeps `HandData.id` attached to the same physical hand: Vision
    /// hands back its observations in no guaranteed order, so matching by
    /// array position would let the two hands trade identities between frames,
    /// and each would inherit whatever the other was dragging.
    static func matchAssignments(
        newPositions: [CGPoint],
        previousPositions: [CGPoint],
        radius: CGFloat
    ) -> [Int?] {
        var claimed = Set<Int>()
        var assignments = [Int?](repeating: nil, count: newPositions.count)

        for (index, position) in newPositions.enumerated() {
            var best: Int?
            var bestDistance = radius
            for (candidate, previous) in previousPositions.enumerated() where !claimed.contains(candidate) {
                let distance = position.distance(to: previous)
                if distance < bestDistance {
                    bestDistance = distance
                    best = candidate
                }
            }
            if let best {
                claimed.insert(best)
                assignments[index] = best
            }
        }
        return assignments
    }

    /// No hand in this frame. Tracking records are kept for `handGracePeriod`
    /// so a hand that blurs out for a moment keeps its identity — only the
    /// published cursors go away immediately.
    private func publishNoHands() {
        let now = CACurrentMediaTime()
        tracked.removeAll { now - $0.lastSeen > handGracePeriod }
        DispatchQueue.main.async {
            if !self.hands.isEmpty { self.hands = [] }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension HandPoseManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        process(pixelBuffer: pixelBuffer)
    }
}

// MARK: - Geometry helper

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
