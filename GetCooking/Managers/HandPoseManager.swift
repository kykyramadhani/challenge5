//
//  HandPoseManager.swift
//  VisionChef
//
//  Captures camera frames, runs VNDetectHumanHandPoseRequest on each frame,
//  tracks up to two hands independently, classifies each as open/closed, and
//  detects fast swipes (horizontal to serve, downward to bin the plate).
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

    // MARK: - Published state consumed by SwiftUI / SpriteKit
    // All writes are dispatched onto the main queue; safe to read from SwiftUI.

    /// Every hand currently tracked, up to `maximumHandCount`.
    @Published private(set) var hands: [HandData] = []

    /// The most recent detected swipe, from whichever hand made it. Consumed
    /// by `GameScene`, which calls `clearSwipe()` once handled.
    @Published private(set) var lastSwipe: SwipeDirection?

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
    /// 1.0 means "as wide as this camera goes"; 1.5 would crop in by half again.
    ///
    /// Left at 1.0 the player can stand back and still have both hands, the
    /// counter and their torso in frame, which is what the grab-and-drag game
    /// needs — the default zoom AVFoundation picks is noticeably tighter.
    var previewZoomFactor: CGFloat = 1.0

    /// How the feed is fitted to the screen.
    ///
    /// `.resizeAspect` shows the *entire* frame — the widest view the camera
    /// has, the way Photo Booth shows it — with letterbox bars wherever the
    /// frame's aspect doesn't match the screen's. `.resizeAspectFill` fills the
    /// screen instead and throws away everything that overflows, which on a
    /// 19.5:9 phone is close to 40% of a 4:3 frame: no amount of widening the
    /// lens survives that crop, so fitting is the default.
    ///
    /// Both `CameraPreviewView` and the hand → screen mapping below read this
    /// one property, so the skeleton can never disagree with the image.
    var previewGravity: AVLayerVideoGravity = .resizeAspect

    /// Whether to switch Center Stage off for this app.
    ///
    /// Center Stage crops deep into the sensor to keep a face centred and
    /// re-frames as the subject moves — the right call on a video call, the
    /// wrong one here. It cuts the player's hands out of frame, moves the
    /// framing mid-game, and raises `minAvailableVideoZoomFactor`, so "zoom all
    /// the way out" only reaches the edge of *its* crop. macOS enables it by
    /// default on MacBook cameras, and it applies to iPad models that have it.
    var disablesCenterStage = true

    /// Bounds on the capture format picked in `selectWidestFormat`. The floor
    /// keeps Vision fed with enough detail to find finger joints; the ceiling
    /// keeps per-frame inference cheap enough to stay ahead of the game loop.
    var minimumCaptureWidth: Int32 = 640
    var maximumCaptureWidth: Int32 = 1920

    /// How many hands to track at once.
    var maximumHandCount = 2

    /// Minimum Vision joint confidence to trust a point.
    var jointConfidenceThreshold: Float = 0.25

    /// A finger counts as "extended" when its tip sits at least this many
    /// *palm lengths* away from the wrist (palm length = wrist → knuckles).
    ///
    /// Measuring against palm length rather than against the finger's own PIP
    /// joint is what makes this work: an extended finger puts its tip at
    /// roughly 1.8–2.2 palm lengths from the wrist, while a curled one folds
    /// back to ~1.0, so 1.5 splits them with room on both sides — and because
    /// the ratio is scale-free it holds at any distance from the camera.
    var extensionRatioThreshold: CGFloat = 1.5

    /// Number of extended fingers (out of 4, thumb excluded) required to
    /// classify a hand as open. `closedFingerCountThreshold` or fewer
    /// classifies it as a fist. Values in between keep that hand's previous
    /// state (hysteresis) to avoid flicker at the boundary.
    var openFingerCountThreshold = 3
    var closedFingerCountThreshold = 1

    /// Rotation used when running on a Mac, which has no device orientation to
    /// follow. Valid angles are 0/90/180/270 only, so -90 must be written 270.
    var macCameraRotationAngle: CGFloat = 90

    /// Exponential smoothing applied to each cursor (0 = frozen, 1 = raw).
    var cursorSmoothing: CGFloat = 0.35

    /// How far (in normalized units) a hand may travel between frames and still
    /// be considered the same hand. Too large and two hands crossing over swap
    /// identities; too small and a fast hand is treated as a brand-new one.
    var handMatchRadius: CGFloat = 0.45

    /// Rolling window of palm positions used for swipe detection.
    private let swipeSampleWindow: TimeInterval = 0.3

    /// Normalized-units-per-second speed required to register a swipe. Tuned
    /// low: a casual flick should land first time, and swipes are only acted on
    /// in contexts where a false positive is cheap (see `GameScene`).
    var swipeVelocityThreshold: CGFloat = 0.9

    /// Net travel required as well as speed, so a slow drift across a long
    /// window can't accumulate into a "swipe".
    var minimumSwipeDistance: CGFloat = 0.10

    /// A swipe must be this many times more horizontal than vertical to count,
    /// so reaching up or down for an ingredient never reads as a serve.
    var swipeAxisDominance: CGFloat = 1.25

    /// Minimum time between two accepted swipes, across all hands — otherwise
    /// both hands moving together fire the same gesture twice.
    var swipeCooldown: TimeInterval = 0.5

    /// How long a hand's trajectory survives after Vision stops reporting it.
    ///
    /// This is what makes fast flicks work: motion blur regularly costs several
    /// frames of tracking mid-swipe, and discarding the history on the first
    /// missed frame threw away the very movement being measured.
    var handGracePeriod: TimeInterval = 0.35

    // MARK: - AVFoundation / Vision plumbing

    /// Shared with `CameraPreviewView` so the AR passthrough layer renders the
    /// same feed Vision reads — iOS won't run two sessions on one camera.
    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.visionchef.camera.session")
    private let videoQueue = DispatchQueue(label: "com.visionchef.camera.video")
    private let handPoseRequest = VNDetectHumanHandPoseRequest()
    private var isConfigured = false

    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservers: [NSKeyValueObservation] = []

    // MARK: - Per-hand tracking (accessed only from videoQueue)

    private struct TimedPoint {
        let point: CGPoint
        let time: TimeInterval
    }

    /// videoQueue-local record of a hand between frames.
    private struct TrackedHand {
        let id: Int
        var smoothed: CGPoint
        var isOpen: Bool
        var recent: [TimedPoint]
        /// Last time Vision actually reported this hand; drives the grace period.
        var lastSeen: TimeInterval
    }

    private var tracked: [TrackedHand] = []
    private var nextHandID = 0
    private var lastSwipeTime: TimeInterval = 0
    private var lastMeasuredBufferSize: CGSize = .zero

    // MARK: - Init

    override init() {
        super.init()
        handPoseRequest.maximumHandCount = maximumHandCount
    }

    // MARK: - Public control

    /// Requests camera permission (if needed) and starts the capture session.
    /// Safe to call multiple times. Call from the main thread (e.g. `.onAppear`).
    func start() {
        handPoseRequest.maximumHandCount = maximumHandCount

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorizationStatus = .authorized
            configureSessionIfNeeded()
            beginRunning()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.authorizationStatus = granted ? .authorized : .denied
                    if granted {
                        self.configureSessionIfNeeded()
                        self.beginRunning()
                    }
                }
            }

        case .denied, .restricted:
            authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

        @unknown default:
            break
        }
    }

    func stop() {
        sessionQueue.async { [captureSession] in
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }

    /// Call after consuming `lastSwipe` so the same swipe isn't handled twice.
    func clearSwipe() {
        lastSwipe = nil
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
            if turnOffCenterStage { Self.disableCenterStage() }

            self.captureSession.beginConfiguration()
            // Fallback only. `selectWidestFormat` below overrides this with a
            // hand-picked format (which flips the preset to `.inputPriority`);
            // the preset matters just for devices where no format qualifies.
            self.captureSession.sessionPreset = .hd1280x720

            guard
                let device = Self.widestCamera(at: position),
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
            Self.selectWidestFormat(on: device, zoom: zoom, widthRange: widthRange)

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

    // MARK: - Choosing the widest view

    /// Switches Center Stage off for this app.
    ///
    /// Center Stage is a system-wide setting the *user* owns — on a MacBook it
    /// lives in Control Center's video menu, and it is on by default there. An
    /// app can only touch it after claiming a share of that control, which is
    /// what `centerStageControlMode` does.
    ///
    /// `.cooperative` rather than `.app` on purpose: it turns the crop off for
    /// play, and still leaves the Control Center toggle live so the setting can
    /// be flipped back while the game is running.
    static func disableCenterStage() {
        // Claiming a share of control is what makes the flag writable at all —
        // setting it under `.user` control raises instead.
        if AVCaptureDevice.centerStageControlMode == .user {
            AVCaptureDevice.centerStageControlMode = .cooperative
        }
        if AVCaptureDevice.isCenterStageEnabled {
            AVCaptureDevice.isCenterStageEnabled = false
        }
    }

    /// The widest-angle camera available at `position`.
    ///
    /// An ultra-wide is asked for first and is what a Mac or a future
    /// wider-lensed device would hand back; every current iPhone/iPad front
    /// camera falls through to the wide-angle one.
    static func widestCamera(at position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        // DiscoverySession returns devices in the order the types were listed.
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: position
        )
        return discovery.devices.first
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    /// Picks the format that sees the most of the room, then zooms all the way
    /// out within it.
    ///
    /// Ranked on horizontal field of view first, because that is what survives
    /// on screen in landscape, then on vertical field of view — which is how a
    /// 4:3 format beats a 16:9 one of the same width. A 16:9 format is usually
    /// the *same* horizontal view with the top and bottom sliced off, so the
    /// tie-break is a free gain in portrait and costs nothing in landscape.
    /// Lowest resolution wins any remaining tie, to keep Vision cheap.
    static func selectWidestFormat(
        on device: AVCaptureDevice,
        zoom: CGFloat,
        widthRange: ClosedRange<Int32>
    ) {
        let candidates = device.formats.filter { format in
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            guard widthRange.contains(dimensions.width), dimensions.height > 0 else { return false }
            // The game runs the tracker every frame; anything slower than 30fps
            // makes a swipe too sparsely sampled to measure.
            return format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 30 }
        }

        let widest = candidates.max { a, b in ranking(of: a) < ranking(of: b) }

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if let widest {
                device.activeFormat = widest
                // Cap the frame rate: switching format resets the duration to
                // the format's default, which can be 60fps on newer devices.
                let thirty = CMTime(value: 1, timescale: 30)
                if widest.videoSupportedFrameRateRanges.contains(where: {
                    $0.minFrameRate <= 30 && $0.maxFrameRate >= 30
                }) {
                    device.activeVideoMinFrameDuration = thirty
                }
            }

            // `minAvailableVideoZoomFactor` is the widest the active format
            // allows — on devices whose default sits above it, this alone is
            // the difference between a head-and-shoulders crop and a view with
            // both hands in it.
            let widestZoom = device.minAvailableVideoZoomFactor
            device.videoZoomFactor = min(
                max(widestZoom * max(zoom, 0.01), widestZoom),
                device.maxAvailableVideoZoomFactor
            )

            #if DEBUG
            let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
            // A zoom floor above 1.0, or Center Stage still active, means
            // something outside the session is cropping the frame.
            print("""
                [HandPoseManager] \(device.localizedName): \
                \(dimensions.width)×\(dimensions.height), \
                \(Int(device.activeFormat.videoFieldOfView))° h-FOV, \
                zoom \(device.videoZoomFactor) (floor \(widestZoom)), \
                Center Stage active: \(device.isCenterStageActive)
                """)
            #endif
        } catch {
            #if DEBUG
            print("[HandPoseManager] couldn't widen the camera: \(error.localizedDescription)")
            #endif
        }
    }

    /// How much of the room a format sees, as `(horizontal°, vertical°,
    /// -pixelWidth)` — compared lexicographically, so each term only breaks a
    /// tie in the one before it.
    ///
    /// AVFoundation reports only the horizontal angle; the vertical one follows
    /// from the frame's aspect ratio through the same pinhole projection.
    static func ranking(of format: AVCaptureDevice.Format) -> (CGFloat, CGFloat, CGFloat) {
        let horizontal = CGFloat(format.videoFieldOfView)
        let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        guard dimensions.width > 0, horizontal > 0 else { return (horizontal, 0, 0) }

        let aspect = CGFloat(dimensions.height) / CGFloat(dimensions.width)
        let halfHorizontal = horizontal * .pi / 360   // degrees → half-angle in radians
        let vertical = 2 * atan(tan(halfHorizontal) * aspect) * 180 / .pi
        return (horizontal, vertical, -CGFloat(dimensions.width))
    }

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

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        do {
            try handler.perform([handPoseRequest])
        } catch {
            publishNoHands()
            return
        }

        let observations = handPoseRequest.results ?? []
        guard !observations.isEmpty else {
            publishNoHands()
            return
        }

        let now = CACurrentMediaTime()
        let classifications = observations.compactMap {
            try? Self.classify(
                observation: $0,
                jointConfidenceThreshold: jointConfidenceThreshold,
                extensionRatioThreshold: extensionRatioThreshold
            )
        }
        guard !classifications.isEmpty else {
            publishNoHands()
            return
        }

        let hands = matchToTrackedHands(classifications, now: now)
        DispatchQueue.main.async { self.hands = hands }
    }

    /// Result of classifying a single Vision hand observation.
    private struct Classification {
        let location: CGPoint // normalized, Vision space — palm centre
        let extendedFingerCount: Int
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
        jointConfidenceThreshold: Float,
        extensionRatioThreshold: CGFloat
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

        // Thumb excluded: it folds sideways rather than curling inward, so it
        // scores badly against a straight wrist-distance test.
        let fingertips: [VNHumanHandPoseObservation.JointName] = [.indexTip, .middleTip, .ringTip, .littleTip]
        let extendedCount = extendedFingerCount(
            wrist: wrist,
            fingertips: fingertips.compactMap(point),
            palmLength: palmLength,
            threshold: extensionRatioThreshold
        )

        // Track the palm centre (wrist + knuckles) rather than including the
        // fingertips: the palm barely moves when the hand opens and closes, so
        // the cursor stays put at the exact moment the player clenches to grab.
        let palmPoints = [wrist] + knucklePoints
        let sum = palmPoints.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        let centre = CGPoint(x: sum.x / CGFloat(palmPoints.count), y: sum.y / CGFloat(palmPoints.count))

        return Classification(
            location: centre,
            extendedFingerCount: extendedCount,
            skeleton: skeleton
        )
    }

    /// How many fingertips sit at least `threshold` palm-lengths from the
    /// wrist. Extracted from `classify` so the tuning maths can be exercised
    /// without having to fabricate a `VNHumanHandPoseObservation`.
    static func extendedFingerCount(
        wrist: CGPoint,
        fingertips: [CGPoint],
        palmLength: CGFloat,
        threshold: CGFloat
    ) -> Int {
        guard palmLength > 0 else { return 0 }
        return fingertips.filter { wrist.distance(to: $0) / palmLength >= threshold }.count
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
                                   isOpen: false, recent: [], lastSeen: now)
                nextHandID += 1
            }
            hand.lastSeen = now

            // Smooth the cursor: Vision's per-frame jitter is easily 20–30pt on
            // screen, enough to slide off an ingredient mid-grab.
            hand.smoothed = CGPoint(
                x: hand.smoothed.x + (classification.location.x - hand.smoothed.x) * cursorSmoothing,
                y: hand.smoothed.y + (classification.location.y - hand.smoothed.y) * cursorSmoothing
            )

            // Hysteresis is per hand, so one hand closing can't flip the other.
            let isOpen: Bool
            if classification.extendedFingerCount >= openFingerCountThreshold {
                isOpen = true
            } else if classification.extendedFingerCount <= closedFingerCountThreshold {
                isOpen = false
            } else {
                isOpen = hand.isOpen
            }
            hand.isOpen = isOpen

            // Swipe velocity is measured on the raw palm centre; smoothing it
            // would damp exactly the fast motion a swipe is made of.
            hand.recent.append(TimedPoint(point: classification.location, time: now))
            hand.recent.removeAll { now - $0.time > swipeSampleWindow }
            detectSwipe(in: &hand, now: now)

            stillTracked.append(hand)
            result.append(HandData(
                id: hand.id,
                cursorPosition: hand.smoothed,
                isOpenHand: isOpen,
                isClosedFist: !isOpen,
                extendedFingerCount: classification.extendedFingerCount,
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

    /// Classifies a stretch of palm travel as a swipe, or nothing.
    ///
    /// Both a speed *and* a net-distance bar must be cleared: speed alone lets
    /// a tiny tracking jitter over a couple of milliseconds read as a flick,
    /// while distance alone lets a slow drift across the window qualify.
    ///
    /// `start`/`end` are in Vision space, where y grows upward.
    static func swipeDirection(
        from start: CGPoint,
        to end: CGPoint,
        over duration: TimeInterval,
        minimumDistance: CGFloat,
        horizontalSpeed: CGFloat,
        dominance: CGFloat
    ) -> SwipeDirection? {
        guard duration >= 0.04 else { return nil }

        let dx = end.x - start.x
        let dy = end.y - start.y
        let velocityX = dx / duration

        guard abs(dx) >= minimumDistance,
              abs(velocityX) >= horizontalSpeed,
              abs(dx) >= abs(dy) * dominance
        else { return nil }

        // The feed is mirrored at the capture connection, so Vision-space x
        // already runs the same way the player sees it.
        return velocityX > 0 ? .right : .left
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

    /// Looks for a flick in a hand's recent trajectory.
    ///
    /// Deliberately makes **no check on finger pose**. Vision's open/closed
    /// classification is the first thing to fall apart under motion blur, which
    /// is precisely when a swipe is happening — requiring `isOpen` here meant
    /// the faster you swiped, the less likely it was to register.
    ///
    /// Measured on the raw palm samples rather than the smoothed cursor:
    /// smoothing exists to steady a pointer, and it damps exactly the sharp
    /// motion a flick is made of.
    private func detectSwipe(in hand: inout TrackedHand, now: TimeInterval) {
        guard now - lastSwipeTime > swipeCooldown,
              let newest = hand.recent.last,
              let oldest = hand.recent.first
        else { return }

        guard let direction = Self.swipeDirection(
            from: oldest.point,
            to: newest.point,
            over: newest.time - oldest.time,
            minimumDistance: minimumSwipeDistance,
            horizontalSpeed: swipeVelocityThreshold,
            dominance: swipeAxisDominance
        ) else { return }

        lastSwipeTime = now
        hand.recent.removeAll()

        DispatchQueue.main.async { self.lastSwipe = direction }
    }

    /// No hand in this frame. Trajectories are kept for `handGracePeriod` so a
    /// blurred-out flick can still be measured when tracking recovers — only
    /// the published cursors go away immediately.
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
