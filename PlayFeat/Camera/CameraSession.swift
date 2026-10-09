//
//  CameraSession.swift
//  PlayFeat
//
//  Runs the front camera: asks for permission, sets the session up (widest
//  format, 2× zoom, Center Stage off, mirrored, video only), keeps it rotated
//  with the device, and hands every frame to `onFrame` on the video queue.
//
//  Knows nothing about hands — that's HandFrameProcessor's job. Shared with
//  CameraPreviewView so the preview shows the same feed Vision reads: iOS
//  won't run two sessions on one camera.
//
//  Threading: everything here runs on the main actor, except the frame
//  callback, which AVFoundation calls on `videoQueue`. That one is marked
//  `nonisolated`, and so is `onFrame`, so the compiler knows exactly which
//  part runs off the main thread.
//

import AVFoundation
import CoreGraphics

final class CameraSession: NSObject {

    // MARK: - Configuration
    //
    // `var` on purpose: tuning knobs, read once when the session is set up.

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
    var zoomFactor: CGFloat = 2.0

    /// How the feed is fitted to the screen. The hand → screen mapping has to
    /// undo exactly this, so both read it from here.
    var previewGravity: AVLayerVideoGravity = .resizeAspectFill

    /// Whether to switch Center Stage off for this app.
    var disablesCenterStage = true

    /// Bounds on the capture format picked in `selectWidestFormat`.
    var minimumCaptureWidth: Int32 = 640
    var maximumCaptureWidth: Int32 = 1920

    /// Rotation used when running on a Mac.
    var macCameraRotationAngle: CGFloat = 90

    // MARK: - Session

    let captureSession = AVCaptureSession()

    /// Called on the video queue for every frame. Set it once, before
    /// `start()`. `nonisolated(unsafe)` because it is written on the main
    /// actor before the camera runs and only read on the video queue after.
    nonisolated(unsafe) var onFrame: (@Sendable (CVPixelBuffer) -> Void)?

    /// Current camera permission.
    var authorizationStatus: AVAuthorizationStatus { permission.authorizationStatus }

    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.reability.playfeat.camera.session")
    private let videoQueue = DispatchQueue(label: "com.reability.playfeat.camera.video")
    private let permission = CameraManager()
    private var isConfigured = false

    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservers: [NSKeyValueObservation] = []

    // MARK: - Start / stop

    /// Requests camera permission (if needed) and starts the session.
    /// `onAuthorization` gets the resulting permission on the main thread.
    /// Safe to call multiple times.
    func start(onAuthorization: @escaping (AVAuthorizationStatus) -> Void) {
        permission.requestCameraPermission { [weak self] granted in
            guard let self else { return }
            onAuthorization(self.permission.authorizationStatus)
            guard granted else { return }
            self.configureSessionIfNeeded()
            self.beginRunning()
        }
    }

    func stop() {
        sessionQueue.async { [captureSession] in
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
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

    // MARK: - Session configuration

    private func configureSessionIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        // Read the tuning knobs here, on the main thread, so the session queue
        // never touches them concurrently with a caller changing them.
        let position = cameraPosition
        let zoom = zoomFactor
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

    // MARK: - Rotation tracking

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
            print("[CameraSession] rotation \(angle)° rejected by the capture connection; feed left as-is.")
            #endif
            return
        }

        previewConnection?.videoRotationAngle = angle

        sessionQueue.async { [weak self] in
            self?.videoOutput.connection(with: .video)?.videoRotationAngle = angle
        }
    }
}

// MARK: - Frames (video queue)

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    /// AVFoundation calls this on `videoQueue`, never on the main thread —
    /// hence `nonisolated`. It only forwards the frame.
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrame?(pixelBuffer)
    }
}
