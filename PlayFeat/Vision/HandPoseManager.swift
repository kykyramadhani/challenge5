//
//  HandPoseManager.swift
//  PlayFeat
//
//  Captures camera frames, runs VNDetectHumanHandPoseRequest on each frame,
//  tracks up to two hands independently, and classifies each as grabbing
//  (thumb tip pinched to index-finger tip) or open (everything else).
//
//  Vision inference runs entirely on a background queue (`videoQueue`); only
//  the observed updates are hopped onto the main queue, so a slow
//  frame never stalls SwiftUI/SpriteKit.
//

import AVFoundation
import Vision
import CoreGraphics
import QuartzCore

@Observable
final class HandPoseManager: NSObject {
    /// Alias for HumanBodyPoseManager's BodyCandidate for backward compatibility.
    typealias BodyCandidate = HumanBodyPoseManager.BodyCandidate

    // MARK: - Published state consumed by SwiftUI / SpriteKit
    // All writes are dispatched onto the main queue; safe to read from SwiftUI.

    /// Every hand currently tracked, up to `maximumHandCount`.
    private(set) var hands: [HandData] = []

    /// The player's upper body in normalized Vision space, nil when nobody is
    /// tracked.
    ///
    /// Exactly one body ever appears here: the nearest. Other people in frame
    /// are never published, however much of them Vision can see.
    private(set) var playerBody: BodyCandidate?

    /// Camera authorization state, surfaced so the UI can prompt the user.
    private(set) var authorizationStatus: AVAuthorizationStatus = .notDetermined

    /// Dimensions of the frames Vision is actually reading, after the capture
    /// connection's rotation. Needed to undo `.resizeAspectFill` cropping when
    /// mapping to the screen — without it the overlay only lines up when the
    /// screen happens to share the camera's 4:3 aspect.
    private(set) var bufferSize: CGSize = .zero
    
    /// The current mapping from Vision points to the screen.
    private var mapping: CameraViewMapping {
        CameraViewMapping(bufferSize: bufferSize, gravity: previewGravity)
    }

    var isHandVisible: Bool { !hands.isEmpty }

    // MARK: - Configuration
    //
    // These are `var` on purpose: hand size, camera distance and lighting all
    // shift the numbers below, so they are tuning knobs, not constants.

    /// Which camera to read frames from.
    @ObservationIgnored var cameraPosition: AVCaptureDevice.Position = .front

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
    @ObservationIgnored var previewZoomFactor: CGFloat = 2.0

    /// How the feed is fitted to the screen.
    @ObservationIgnored var previewGravity: AVLayerVideoGravity = .resizeAspectFill

    /// Whether to switch Center Stage off for this app.
    @ObservationIgnored var disablesCenterStage = true

    /// Bounds on the capture format picked in `selectWidestFormat`.
    @ObservationIgnored var minimumCaptureWidth: Int32 = 640
    @ObservationIgnored var maximumCaptureWidth: Int32 = 1920

    /// How many hands to actually play with — one player, two hands.
    @ObservationIgnored var maximumHandCount = 2

    /// How many hands Vision may report before the single-player filter runs.
    @ObservationIgnored var handCandidateLimit = 4

    /// Whether hands are gated on the body they are attached to.
    @ObservationIgnored var tracksSinglePlayer = true

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
    @ObservationIgnored var jointConfidenceThreshold: Float = 0.25 {
        didSet { bodyPoseManager.jointConfidenceThreshold = jointConfidenceThreshold }
    }

    /// Rotation used when running on a Mac.
    @ObservationIgnored var macCameraRotationAngle: CGFloat = 90

    // MARK: - AVFoundation / Vision plumbing

    /// Shared with `CameraPreviewView` so the AR passthrough layer renders the
    /// same feed Vision reads — iOS won't run two sessions on one camera.
    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.visionchef.camera.session")
    private let videoQueue = DispatchQueue(label: "com.visionchef.camera.video")
    private let handPoseRequest = VNDetectHumanHandPoseRequest()
    private let bodyPoseManager = HumanBodyPoseManager()
    
    @ObservationIgnored private var isConfigured = false

    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    @ObservationIgnored private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    @ObservationIgnored private var rotationObservers: [NSKeyValueObservation] = []

    // MARK: - Per-hand tracking (accessed only from videoQueue)

    /// Keeps each hand's ID, smoothed cursor and pinch state between frames.
    /// The hand-tracking tuning knobs (smoothing, grace period, pinch
    /// thresholds) live on it.
    @ObservationIgnored private var identityTracker = HandIdentityTracker()

    @ObservationIgnored private var lastMeasuredBufferSize: CGSize = .zero

    /// videoQueue-local copy of what was last published, so an unchanged body
    /// doesn't hop onto the main queue every frame.
    @ObservationIgnored private var lastPublishedBody: BodyCandidate?

    private let cameraManager = CameraManager.init()

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
        mapping.viewPoint(hand.cursorPosition, in: size)
    }

    /// A hand's skeleton mapped into view space, one chain per finger.
    func jointChains(for hand: HandData, in size: CGSize) -> [[CGPoint]] {
        hand.skeleton.map { chain in chain.map { mapping.viewPoint($0, in: size) } }
    }

    /// The player's upper body in view space. Runs through the same mapping as
    /// the hands, so the two can never disagree about where the player is.
    func playerBody(in size: CGSize) -> BodyCandidate? {
        playerBody?.mapped { mapping.viewPoint($0, in: size) }
    }

    /// The player's body as bone chains in view space, one chain per bone.
    func bodyChains(in size: CGSize) -> [[CGPoint]] {
        playerBody(in: size)?.chains ?? []
    }

    /// Every joint of a hand in view space, as a flat list.
    func jointPoints(for hand: HandData, in size: CGSize) -> [CGPoint] {
        hand.recognizedJoints.map { mapping.viewPoint($0, in: size) }
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
            try? HandClassifier.classify($0, jointConfidenceThreshold: jointConfidenceThreshold)
        }
        guard !classifications.isEmpty else {
            publishNoHands()
            return
        }

        let mode = HandInputModeSetting.stored()

        // No body, no hands. A hand is only the player's if it can be tied to
        // a visible shoulder, so a torso out of frame means nothing is tracked
        // — the same rule the seat check enforces before the game even starts.
        let keep = HumanBodyPoseManager.playerHandIndices(
            handWrists: classifications.map(\.wrist),
            bodies: bodies,
            wristTolerance: wristMatchTolerance,
            limit: min(maximumHandCount, mode.handCount),
            mode: mode
        ) ?? []

        let hands = identityTracker.update(with: keep.map { classifications[$0] }, at: now)
        DispatchQueue.main.async { self.hands = hands }
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
        mode: any HandInputMode = TwoHandMode()
    ) -> [Int]? {
        HumanBodyPoseManager.playerHandIndices(
            handWrists: handWrists,
            bodies: bodies,
            wristTolerance: wristTolerance,
            limit: limit,
            mode: mode
        )
    }

    /// Vision found nothing usable this frame.
    ///
    /// Runs the *same* coasting rule as a frame that did find hands: anything
    /// still inside the grace period keeps being published at its last known
    /// position, and only a hand that has been missing longer than that
    /// actually goes away. This used to blank the published list outright,
    /// which is what made a single dropped frame kill the aura.
    private func publishNoHands() {
        let hands = identityTracker.update(with: [], at: CACurrentMediaTime())
        DispatchQueue.main.async {
            if self.hands != hands { self.hands = hands }
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
