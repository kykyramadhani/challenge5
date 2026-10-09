//
//  HandPoseManager.swift
//  PlayFeat
//
//  The app's source of hand tracking. Wires the camera (CameraSession) to the
//  frame pipeline (HandFrameProcessor) and publishes the result — the player's
//  hands and body — on the main thread for SwiftUI and the game scene.
//
//  Threading: frames arrive on the camera's video queue and are processed
//  there, off the main thread, so a slow frame never stalls SwiftUI or
//  SpriteKit. Only the finished result hops to the main thread, once per
//  frame.
//

import AVFoundation
import CoreGraphics
import Vision

@Observable
final class HandPoseManager {
    /// Alias for HumanBodyPoseManager's BodyCandidate for backward compatibility.
    typealias BodyCandidate = HumanBodyPoseManager.BodyCandidate

    // MARK: - Published state consumed by SwiftUI / SpriteKit
    // Only written on the main thread.

    /// Every hand currently tracked, up to the input mode's hand count.
    private(set) var hands: [HandData] = []

    /// The player's upper body in normalized Vision space, nil when nobody is
    /// tracked.
    ///
    /// Exactly one body ever appears here: the nearest. Other people in frame
    /// are never published, however much of them Vision can see.
    private(set) var playerBody: BodyCandidate?

    /// Camera authorization state, surfaced so the UI can prompt the user.
    private(set) var authorizationStatus: AVAuthorizationStatus

    /// Dimensions of the frames Vision is actually reading, after the capture
    /// connection's rotation. Needed to undo `.resizeAspectFill` cropping when
    /// mapping to the screen — without it the overlay only lines up when the
    /// screen happens to share the camera's 4:3 aspect.
    private(set) var bufferSize: CGSize = .zero

    var isHandVisible: Bool { !hands.isEmpty }

    // MARK: - Camera and pipeline

    /// The camera. Tuning (zoom, Center Stage, capture width) lives on it.
    let camera = CameraSession()

    /// Turns frames into hands, on the video queue. Tuning (hand limits,
    /// joint confidence, wrist tolerance) lives on it.
    let processor = HandFrameProcessor()

    /// Shared with `CameraPreviewView` so the preview renders the same feed
    /// Vision reads — iOS won't run two sessions on one camera.
    var captureSession: AVCaptureSession { camera.captureSession }

    /// How the feed is fitted to the screen.
    var previewGravity: AVLayerVideoGravity { camera.previewGravity }

    /// The current mapping from Vision points to the screen.
    private var mapping: CameraViewMapping {
        CameraViewMapping(bufferSize: bufferSize, gravity: previewGravity)
    }

    init() {
        authorizationStatus = camera.authorizationStatus

        // Runs on the video queue: process there, publish on the main thread.
        let processor = self.processor
        camera.onFrame = { [weak self] pixelBuffer in
            let frame = processor.process(pixelBuffer)
            guard let self else { return }
            DispatchQueue.main.async { self.publish(frame) }
        }
    }

    // MARK: - Public control

    /// Requests camera permission (if needed) and starts the camera.
    /// Safe to call multiple times. Call from the main thread (e.g. `.onAppear`).
    func start() {
        camera.start { [weak self] status in
            self?.authorizationStatus = status
        }
    }

    func stop() {
        camera.stop()
    }

    /// Handed over by `CameraPreviewView` so rotation follows what's on screen.
    func attach(previewLayer layer: AVCaptureVideoPreviewLayer) {
        camera.attach(previewLayer: layer)
    }

    /// Writes one frame's result. Only changed values are written, so views
    /// that read an unchanged value don't redraw.
    private func publish(_ frame: HandFrameProcessor.Output) {
        if bufferSize != frame.bufferSize { bufferSize = frame.bufferSize }
        if playerBody != frame.playerBody { playerBody = frame.playerBody }
        if hands != frame.hands { hands = frame.hands }
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
}
