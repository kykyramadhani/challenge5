//
//  HandFrameProcessor.swift
//  PlayFeat
//
//  Everything done to one camera frame, in order:
//
//    1. Vision: hand pose (every frame) + body pose (every Nth frame)
//    2. Body: who the player is (the nearest person)
//    3. HandClassifier: palm, wrist and pinch gap for each hand Vision saw
//    4. Body filter: keep only the player's hands, for the current input mode
//    5. HandIdentityTracker: stable IDs, smoothing, pinch state, coasting
//
//  Runs on the camera's video queue, so it is `nonisolated` and owns all of
//  its state — nothing here is touched from the main thread. The result of
//  each frame goes back as one `Output`, which HandPoseManager publishes on
//  the main thread.
//

import CoreGraphics
import QuartzCore
import Vision

/// `@unchecked Sendable`: handed to the camera's frame callback, and only
/// ever used from the video queue, one frame at a time.
nonisolated final class HandFrameProcessor: @unchecked Sendable {

    /// What one frame produced.
    struct Output {
        /// Size of the frame Vision read, after rotation.
        let bufferSize: CGSize
        /// The player's body (nearest person), nil when nobody is tracked.
        let playerBody: HumanBodyPoseManager.BodyCandidate?
        /// The player's hands, with stable IDs, including coasting ones.
        let hands: [HandData]
    }

    // MARK: - Configuration
    //
    // Tuning knobs. Set them before the camera starts: after that they are
    // read on the video queue.

    /// How many hands to actually play with — one player, two hands.
    var maximumHandCount = 2

    /// How many hands Vision may report before the single-player filter runs.
    var handCandidateLimit = 4 {
        didSet { handPoseRequest.maximumHandCount = handCandidateLimit }
    }

    /// Whether hands are gated on the body they are attached to.
    var tracksSinglePlayer = true

    /// Minimum Vision joint confidence to trust a point.
    var jointConfidenceThreshold: Float = 0.25 {
        didSet { bodyPoseManager.jointConfidenceThreshold = jointConfidenceThreshold }
    }

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

    // MARK: - State (video queue only)

    private let handPoseRequest = VNDetectHumanHandPoseRequest()
    private let bodyPoseManager = HumanBodyPoseManager()

    /// Keeps each hand's ID, smoothed cursor and pinch state between frames.
    private var identityTracker = HandIdentityTracker()

    /// The last player body, kept for frames where body pose doesn't run or
    /// Vision fails.
    private var playerBody: HumanBodyPoseManager.BodyCandidate?

    init() {
        handPoseRequest.maximumHandCount = handCandidateLimit
    }

    // MARK: - One frame

    func process(_ pixelBuffer: CVPixelBuffer) -> Output {
        // Dimensions come from the delivered buffer, so they already account
        // for whatever rotation the connection is applying.
        let bufferSize = CGSize(
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer)
        )

        // One handler for whatever runs this frame: the image is decoded once.
        let runsBodyPose = bodyPoseManager.shouldRunBodyPose(tracksSinglePlayer: tracksSinglePlayer)

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        do {
            try handler.perform(runsBodyPose ? [handPoseRequest, bodyPoseManager.bodyPoseRequest]
                                             : [handPoseRequest])
        } catch {
            return Output(bufferSize: bufferSize, playerBody: playerBody, hands: handsWhenNoneSeen())
        }

        // Everyone else in the room is ignored from here on. Resolved before
        // the hand guards below, so the skeleton keeps up with the player even
        // in the frames where their hands are down or out of shot — otherwise
        // the last body drawn would stay frozen on screen.
        if runsBodyPose {
            _ = bodyPoseManager.processObservations(bodyPoseManager.bodyPoseRequest.results)
        }
        let bodies = tracksSinglePlayer ? bodyPoseManager.lastBodies : []

        // Only the nearest body, so what is drawn is always exactly who the
        // game is listening to.
        playerBody = bodyPoseManager.resolvePlayer(from: bodies)

        let observations = handPoseRequest.results ?? []
        let classifications = observations.compactMap {
            try? HandClassifier.classify($0, jointConfidenceThreshold: jointConfidenceThreshold)
        }
        guard !classifications.isEmpty else {
            return Output(bufferSize: bufferSize, playerBody: playerBody, hands: handsWhenNoneSeen())
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

        let hands = identityTracker.update(with: keep.map { classifications[$0] }, at: CACurrentMediaTime())
        return Output(bufferSize: bufferSize, playerBody: playerBody, hands: hands)
    }

    /// Vision found nothing usable this frame.
    ///
    /// Runs the *same* coasting rule as a frame that did find hands: anything
    /// still inside the grace period keeps being published at its last known
    /// position, and only a hand that has been missing longer than that
    /// actually goes away. Blanking the list outright is what used to make a
    /// single dropped frame kill the aura.
    private func handsWhenNoneSeen() -> [HandData] {
        identityTracker.update(with: [], at: CACurrentMediaTime())
    }
}
