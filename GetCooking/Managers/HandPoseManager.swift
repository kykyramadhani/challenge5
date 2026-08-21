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
    ///
    /// `.resizeAspectFill` scales the frame to cover the screen and crops
    /// whatever overflows. `.resizeAspect` would show the *entire* frame
    /// instead, but leaves letterbox bars wherever the frame's aspect doesn't
    /// match the screen's — and nothing paints those bars, so they pick up the
    /// SwiftUI background and render as a white slab under the plate and bin.
    ///
    /// Filling costs roughly 7% of the frame's width on an iPad, which is
    /// cheap. It costs close to 40% on a 19.5:9 phone, where it starts pushing
    /// the player's hands out of frame.
    /// ponytail: one gravity for every device; choose it per screen aspect at
    /// runtime if this ever ships on phones.
    ///
    /// Both `CameraPreviewView` and the hand → screen mapping below read this
    /// one property, so the skeleton can never disagree with the image.
    var previewGravity: AVLayerVideoGravity = .resizeAspectFill

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

    /// How many hands to actually play with — one player, two hands.
    var maximumHandCount = 2

    /// How many hands Vision may report before the single-player filter runs.
    ///
    /// Deliberately higher than `maximumHandCount`: a bystander's hand can
    /// out-score the player's second hand, and if Vision is only ever allowed
    /// to return two then the hand that gets dropped is the player's own. The
    /// filter needs spare candidates to choose between.
    var handCandidateLimit = 4

    /// Whether hands are gated on the body they are attached to.
    ///
    /// This is what keeps a bystander out of the game. Costs a second Vision
    /// pass; turn it off to get that back entirely.
    var tracksSinglePlayer = true

    /// Run the body detector on one frame in this many, reusing the last
    /// result in between.
    ///
    /// A torso does not move like a hand. At a third of the rate the player's
    /// shoulders are still where the filter thinks they are, and two thirds of
    /// the second model's cost comes off the frame budget. Hand pose stays at
    /// full rate — grabs are frame-sensitive in a way sitting still is not.
    ///
    /// Running both models flat out at 1920×1440 kept `videoQueue` busy enough
    /// that main-thread work waiting on the capture pipeline stalled for
    /// seconds at a time.
    var bodyPoseFrameInterval = 3

    /// How far a hand's own wrist may sit from a body's wrist and still count
    /// as that body's, as a multiple of that body's shoulder span.
    ///
    /// Expressed against shoulder span rather than in absolute units so it
    /// holds at any distance from the camera. Generous, because the two
    /// detectors disagree slightly about where a wrist is.
    var wristMatchTolerance: CGFloat = 0.6

    /// How much larger or smaller than the anchor hand another hand may
    /// measure and still count as the same person's.
    ///
    /// Only used as the fallback when no body is found at all — see
    /// `onePersonHandIndices`.
    var samePersonScaleTolerance: CGFloat = 1.7

    /// Furthest another hand may sit from the anchor, in normalized units, in
    /// the same no-body fallback.
    var samePersonMaxSpan: CGFloat = 0.7

    /// Minimum Vision joint confidence to trust a point.
    var jointConfidenceThreshold: Float = 0.25

    /// Grabbing is a **pinch**: thumb tip and index-finger tip brought
    /// together. Measured as the gap between those two tips divided by palm
    /// length (wrist → knuckles), so it is scale-free and holds at any
    /// distance from the camera, the same way every other pose measurement
    /// here works.
    ///
    /// Tips touching read at roughly 0.1–0.25 palm lengths (they never reach 0
    /// — the joints sit inside the fingers); an open hand holds them around
    /// 0.8–1.2 apart. The two thresholds give hysteresis: at or below
    /// `pinchCloseRatio` the hand is grabbing, at or above `pinchOpenRatio` it
    /// is open, and in between it keeps whatever it was, so a hand hovering
    /// right at the boundary doesn't flicker and drop what it's carrying.
    ///
    /// Anything that isn't an active pinch counts as open — including a
    /// clenched fist, which used to be the grab pose. Note that the thumb
    /// folds *across* the index finger in a fist, so these two tips land
    /// nearer each other than a thumb-to-little-finger pinch would; the
    /// thresholds are set tight enough to keep that clear of a real pinch, and
    /// are the first thing to lower if fists start registering as grabs.
    var pinchCloseRatio: CGFloat = 0.3
    var pinchOpenRatio: CGFloat = 0.5

    /// Rotation used when running on a Mac, which has no device orientation to
    /// follow. Valid angles are 0/90/180/270 only, so -90 must be written 270.
    var macCameraRotationAngle: CGFloat = 90

    /// Exponential smoothing applied to each cursor (0 = frozen, 1 = raw).
    var cursorSmoothing: CGFloat = 0.35

    /// How far (in normalized units) a hand may travel between frames and still
    /// be considered the same hand. Too large and two hands crossing over swap
    /// identities; too small and a fast hand is treated as a brand-new one.
    var handMatchRadius: CGFloat = 0.45

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

    /// Runs alongside the hand request on the same frame, so the two share one
    /// decode of the image rather than each paying for their own.
    private let bodyPoseRequest = VNDetectHumanBodyPoseRequest()
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

    /// Bodies from the most recent frame that actually ran the detector, held
    /// for the frames in between. See `bodyPoseFrameInterval`.
    private var lastBodies: [BodyCandidate] = []
    private var frameCounter = 0

    // MARK: - Init

    override init() {
        super.init()
        handPoseRequest.maximumHandCount = handCandidateLimit
    }

    // MARK: - Public control

    /// Requests camera permission (if needed) and starts the capture session.
    /// Safe to call multiple times. Call from the main thread (e.g. `.onAppear`).
    func start() {
        handPoseRequest.maximumHandCount = handCandidateLimit

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
    /// Highest resolution wins any remaining tie — the preview is full-screen
    /// on a Retina panel, so a small format is visibly soft. The cost stays
    /// bounded by `maximumCaptureWidth`, which is what keeps Vision affordable.
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
            device.videoZoomFactor = zoomFactor(
                multiple: zoom,
                widest: widestZoom,
                maximum: device.maxAvailableVideoZoomFactor
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

    /// Turns a zoom given as a *multiple of the widest the hardware allows*
    /// into an actual `videoZoomFactor`, clamped to the active format.
    ///
    /// The multiple is what the rest of the code reasons in: 1.0 is "as wide
    /// as this camera goes" wherever the floor happens to sit, which differs
    /// per device and moves when Center Stage is on. Dropping below the floor
    /// or above the ceiling raises, so both ends are clamped.
    static func zoomFactor(multiple: CGFloat, widest: CGFloat, maximum: CGFloat) -> CGFloat {
        min(max(widest * max(multiple, 0.01), widest), maximum)
    }

    /// How much of the room a format sees, as `(horizontal°, vertical°,
    /// pixelWidth)` — compared lexicographically, so each term only breaks a
    /// tie in the one before it.
    static func ranking(of format: AVCaptureDevice.Format) -> (CGFloat, CGFloat, CGFloat) {
        let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        return ranking(
            horizontalFieldOfView: CGFloat(format.videoFieldOfView),
            width: dimensions.width,
            height: dimensions.height
        )
    }

    /// The ordering itself, split out from the `AVCaptureDevice.Format`
    /// overload above because a format can't be constructed in a test.
    ///
    /// AVFoundation reports only the horizontal angle; the vertical one follows
    /// from the frame's aspect ratio through the same pinhole projection.
    ///
    /// Resolution ranks **highest-first**. Every resolution of one sensor
    /// reports the same field of view, so this last term is what actually
    /// picks the format — ranking it lowest-first is what fed a 640×480 image
    /// to a full-screen Retina preview and made the feed look blurry.
    static func ranking(
        horizontalFieldOfView horizontal: CGFloat,
        width: Int32,
        height: Int32
    ) -> (CGFloat, CGFloat, CGFloat) {
        guard width > 0, horizontal > 0 else { return (horizontal, 0, CGFloat(width)) }

        let aspect = CGFloat(height) / CGFloat(width)
        let halfHorizontal = horizontal * .pi / 360   // degrees → half-angle in radians
        let vertical = 2 * atan(tan(halfHorizontal) * aspect) * 180 / .pi
        return (horizontal, vertical, CGFloat(width))
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

        // One handler for whatever runs this frame: the image is decoded once.
        let runsBodyPose = tracksSinglePlayer
            && frameCounter % max(bodyPoseFrameInterval, 1) == 0
        frameCounter &+= 1

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        do {
            try handler.perform(runsBodyPose ? [handPoseRequest, bodyPoseRequest]
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
            lastBodies = (bodyPoseRequest.results ?? []).compactMap {
                Self.bodyCandidate(from: $0, jointConfidenceThreshold: jointConfidenceThreshold)
            }
        }
        let bodies = tracksSinglePlayer ? lastBodies : []

        // Publish the nearest body and only that one, so what is drawn is
        // always exactly who the game is listening to.
        let player = Self.nearestBody(in: bodies).map { bodies[$0] }
        if player != lastPublishedBody {
            lastPublishedBody = player
            DispatchQueue.main.async { self.playerBody = player }
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

        let keep = Self.playerHandIndices(
            handWrists: classifications.map(\.wrist),
            bodies: bodies,
            wristTolerance: wristMatchTolerance,
            limit: handLimit,
            requiredHand: oneHandPreference
        ) ?? Self.onePersonHandIndices(
            // No body to anchor on — a torso cropped out of frame, or the
            // detector losing the player for a frame. Falling back to the
            // geometric guess keeps the game playable; blanking every hand
            // because a shoulder went missing would not. There's no chirality
            // signal here to honor the chosen side with, so one-hand mode
            // still just caps it to a single hand.
            positions: classifications.map(\.location),
            palmLengths: classifications.map(\.palmLength),
            maxSpan: samePersonMaxSpan,
            scaleTolerance: samePersonScaleTolerance,
            limit: handLimit
        )

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

    /// One person's worth of body joints, cut down to what the hand filter
    /// needs. Plain data, so the matching below can be tested without
    /// fabricating a `VNHumanBodyPoseObservation`.
    /// One person's upper body, cut down to what the game needs. Plain data,
    /// so the matching below can be tested without fabricating a
    /// `VNHumanBodyPoseObservation`.
    ///
    /// Shoulders only, plus hips when they happen to be in shot. Legs are
    /// never read: the player is framed from the chest up as often as not, and
    /// a detector that needs legs would lose them every time they stepped in.
    struct BodyCandidate: Equatable {
        /// Nose, or an ear when the head is turned. Used by the seat check —
        /// not drawn, since the skeleton is shoulders and hips.
        let head: CGPoint?

        let leftShoulder: CGPoint
        let rightShoulder: CGPoint

        /// Optional — visible only when the player is framed wide enough. Each
        /// side stands alone, since a turned body can show just the one.
        let leftHip: CGPoint?
        let rightHip: CGPoint?

        /// Whichever wrists Vision was confident about — nil when that side
        /// wasn't seen. Kept as separate sides (rather than a merged list) so
        /// one-hand mode can require *the chosen* wrist, not just any wrist.
        let leftWrist: CGPoint?
        let rightWrist: CGPoint?

        /// Whichever wrists Vision was confident about — 0, 1 or 2 of them.
        /// Empty is legitimate: the player is there, their hands are not.
        var wrists: [CGPoint] { [leftWrist, rightWrist].compactMap { $0 } }

        /// Apparent shoulder span: how near this person is, and the yardstick
        /// the wrist tolerance is measured in.
        ///
        /// Shoulder span rather than a bounding box of the joints. A box grows
        /// the moment someone raises their arms — which would read as stepping
        /// towards the camera — and grows again when their legs are in shot,
        /// which would let a distant full-body bystander outrank a near player.
        var scale: CGFloat { leftShoulder.distance(to: rightShoulder) }

        /// The bones drawn on screen: the shoulder line, and the sides of the
        /// torso down to whichever hips are visible.
        var chains: [[CGPoint]] {
            var chains = [[leftShoulder, rightShoulder]]
            if let leftHip { chains.append([leftShoulder, leftHip]) }
            if let rightHip { chains.append([rightShoulder, rightHip]) }
            if let leftHip, let rightHip { chains.append([leftHip, rightHip]) }
            return chains
        }

        /// The same body with every joint run through `transform` — used to
        /// carry it from Vision's normalized space into view space, so it can
        /// be checked against something the player can actually see.
        func mapped(_ transform: (CGPoint) -> CGPoint) -> BodyCandidate {
            BodyCandidate(
                head: head.map(transform),
                leftShoulder: transform(leftShoulder),
                rightShoulder: transform(rightShoulder),
                leftHip: leftHip.map(transform),
                rightHip: rightHip.map(transform),
                leftWrist: leftWrist.map(transform),
                rightWrist: rightWrist.map(transform)
            )
        }

        /// Whether the player is sitting the way the game needs: head,
        /// shoulders and the required hand(s) inside `frame`, far enough back
        /// that they all fit, close enough that the shoulders still span a
        /// decent share of it.
        ///
        /// The rest of the body is free to fall outside — only what the game
        /// actually tracks has to be in shot. `requiredHand` nil means both
        /// wrists are required (the default two-handed pose the silhouette
        /// shows); a specific side is one-hand mode asking for just that hand.
        func isAligned(
            in frame: CGRect,
            minimumShoulderSpan: CGFloat,
            requiredHand: HandSide? = nil
        ) -> Bool {
            guard let head else { return false }

            let requiredWrists: [CGPoint]
            if let requiredHand {
                guard let wrist = requiredHand == .left ? leftWrist : rightWrist else { return false }
                requiredWrists = [wrist]
            } else {
                guard wrists.count == 2 else { return false }
                requiredWrists = wrists
            }

            let required = [head, leftShoulder, rightShoulder] + requiredWrists
            guard required.allSatisfy(frame.contains) else { return false }

            return scale >= minimumShoulderSpan
        }
    }

    /// Reduces a Vision body observation to the upper body.
    ///
    /// Both shoulders are required — they are the anchor and the yardstick.
    /// Everything else is optional.
    static func bodyCandidate(
        from observation: VNHumanBodyPoseObservation,
        jointConfidenceThreshold: Float
    ) -> BodyCandidate? {
        guard let points = try? observation.recognizedPoints(.all) else { return nil }

        func point(_ name: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
            guard let joint = points[name], joint.confidence >= jointConfidenceThreshold else {
                return nil
            }
            return CGPoint(x: joint.location.x, y: joint.location.y)
        }

        guard let leftShoulder = point(.leftShoulder),
              let rightShoulder = point(.rightShoulder),
              leftShoulder.distance(to: rightShoulder) > 0
        else { return nil }

        return BodyCandidate(
            // Nose first; an ear carries the head just as well once it turns.
            head: point(.nose) ?? point(.leftEar) ?? point(.rightEar),
            leftShoulder: leftShoulder,
            rightShoulder: rightShoulder,
            leftHip: point(.leftHip),
            rightHip: point(.rightHip),
            // Swapped on purpose: the capture connection mirrors the buffer
            // before Vision ever sees it (see the isVideoMirrored setup
            // below), so Vision's own left/right wrist labels come out
            // anatomically backwards — what it calls the left wrist is the
            // player's actual right one.
            leftWrist: point(.rightWrist),
            rightWrist: point(.leftWrist)
        )
    }

    /// The body nearest the camera — the widest shoulders on screen.
    ///
    /// That one is the player. Everybody else in frame is ignored outright,
    /// however much of them is visible.
    static func nearestBody(in bodies: [BodyCandidate]) -> Int? {
        bodies.indices
            .filter { bodies[$0].scale > 0 }
            .max { bodies[$0].scale < bodies[$1].scale }
    }

    /// Picks the hands belonging to the player, using the bodies Vision found
    /// in the same frame.
    ///
    /// The player is the **nearest** body — the widest shoulders on screen. A
    /// hand is kept only when it sits near one of that body's wrists *and* is
    /// not nearer to somebody else's.
    ///
    /// Matching wrist-to-wrist is what makes this hold when the player has only
    /// one hand up, which pure geometry could not: with nothing of the player's
    /// to compare against, a lone bystander hand looks exactly like a second
    /// player hand. Here it is near *their* wrist, so it is theirs.
    ///
    /// Returns nil when no usable body was found — the caller's signal to fall
    /// back rather than blank every hand on screen.
    ///
    /// `requiredHand` is one-hand mode: nil matches either of the player's
    /// wrists (the normal, two-handed rule); a specific side matches only
    /// that wrist, so the other hand is dropped exactly like a bystander's.
    static func playerHandIndices(
        handWrists: [CGPoint],
        bodies: [BodyCandidate],
        wristTolerance: CGFloat,
        limit: Int,
        requiredHand: HandSide? = nil
    ) -> [Int]? {
        guard limit > 0 else { return [] }
        guard let player = nearestBody(in: bodies) else { return nil }

        let reach = bodies[player].scale * wristTolerance

        // A player with no visible wrists legitimately matches nothing: they
        // are in frame, their hands are not. That returns an empty list rather
        // than nil, so the caller does *not* fall back — falling back is what
        // would let a bystander's hands in through the side door.
        func nearestWrist(of body: Int, to hand: CGPoint) -> CGFloat {
            bodies[body].wrists.map { $0.distance(to: hand) }.min() ?? .greatestFiniteMagnitude
        }

        // The player's own wrist(s) to match against — both by default, or
        // just the chosen side in one-hand mode.
        let playerWrists: [CGPoint] = {
            guard let requiredHand else { return bodies[player].wrists }
            let wrist = requiredHand == .left ? bodies[player].leftWrist : bodies[player].rightWrist
            return wrist.map { [$0] } ?? []
        }()

        let matched: [(index: Int, distance: CGFloat)] = handWrists.indices.compactMap { index in
            let hand = handWrists[index]

            let toPlayer = playerWrists.map { $0.distance(to: hand) }.min() ?? .greatestFiniteMagnitude
            guard toPlayer <= reach else { return nil }

            // Nearer to someone else's wrist means it is on their arm, even if
            // it also happens to fall inside the player's reach.
            let toOthers = bodies.indices
                .filter { $0 != player && bodies[$0].scale > 0 }
                .map { nearestWrist(of: $0, to: hand) }
                .min() ?? .greatestFiniteMagnitude
            guard toPlayer <= toOthers else { return nil }

            return (index, toPlayer)
        }

        return matched
            .sorted { $0.distance < $1.distance }
            .prefix(limit)
            .map(\.index)
    }

    /// Narrows a frame's hands down to the ones that plausibly belong to a
    /// single person, on geometry alone.
    ///
    /// The fallback for when no body is detected. Kept because it degrades
    /// better than showing nothing, but `playerHandIndices` is the real filter.
    ///
    /// Anchored on the **largest palm**, which is the hand nearest the lens and
    /// therefore the person the iPad is pointed at. Another hand joins it when
    /// it measures a similar size (so it is at a similar distance) and sits
    /// close enough to hang off the same body.
    ///
    /// Apparent hand size is the load-bearing signal here. Someone standing
    /// behind the player measures visibly smaller, and no amount of arm-waving
    /// changes that, whereas position alone can't tell a second player from the
    /// player's own outstretched hand.
    ///
    /// ponytail: geometry only, no notion of *whose* body a hand is on. If two
    /// people stand shoulder to shoulder at the same distance this will happily
    /// mix them; pairing hands to torsos needs `VNDetectHumanRectanglesRequest`
    /// (cheap) or `VNDetectHumanBodyPoseRequest` (a second inference pass per
    /// frame) — see the note in this method's tests.
    ///
    /// Returns indices into the input, anchor first, at most `limit` of them.
    static func onePersonHandIndices(
        positions: [CGPoint],
        palmLengths: [CGFloat],
        maxSpan: CGFloat,
        scaleTolerance: CGFloat,
        limit: Int
    ) -> [Int] {
        guard limit > 0, positions.count == palmLengths.count,
              let anchor = palmLengths.indices.max(by: { palmLengths[$0] < palmLengths[$1] }),
              palmLengths[anchor] > 0,
              scaleTolerance >= 1
        else { return [] }

        let anchorPalm = palmLengths[anchor]
        let anchorPosition = positions[anchor]

        func distanceToAnchor(_ index: Int) -> CGFloat {
            positions[index].distance(to: anchorPosition)
        }

        let sameBody = positions.indices.filter { index in
            guard index != anchor else { return false }
            let ratio = palmLengths[index] / anchorPalm
            guard ratio >= 1 / scaleTolerance, ratio <= scaleTolerance else { return false }
            return distanceToAnchor(index) <= maxSpan
        }

        // Nearest first, so if more hands qualify than can be played with, the
        // ones dropped are the least likely to be the player's own.
        let ranked = sameBody.sorted { distanceToAnchor($0) < distanceToAnchor($1) }
        return [anchor] + ranked.prefix(limit - 1)
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
