//
//  HumanBodyPoseManager.swift
//  GetCooking
//
//  Manages human body pose detection using Vision (VNDetectHumanBodyPoseRequest),
//  tracks the nearest player body, isolates player hands from bystanders, and
//  handles seat alignment verification.
//

import AVFoundation
import CoreGraphics
import Foundation
import QuartzCore
import Vision

final class HumanBodyPoseManager {
    // MARK: - Types

    /// One person's upper body, cut down to what the game needs.
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

    // MARK: - Vision Requests & State

    let bodyPoseRequest = VNDetectHumanBodyPoseRequest()

    /// Run the body detector on one frame in this many, reusing the last
    /// result in between.
    var bodyPoseFrameInterval = 3

    /// How far a hand's own wrist may sit from a body's wrist and still count
    /// as that body's, as a multiple of that body's shoulder span.
    var wristMatchTolerance: CGFloat = 0.6

    /// Minimum Vision joint confidence to trust a point.
    var jointConfidenceThreshold: Float = 0.25

    /// How long the last seen bodies stand in when the detector comes back
    /// empty.
    ///
    /// Body pose only runs on one frame in `bodyPoseFrameInterval`, so a
    /// single miss would otherwise leave the game with no body — and hence no
    /// hands, since hands are matched to a shoulder — for several frames
    /// running. That was a visible strobe on the aura.
    var bodyGracePeriod: TimeInterval = 0.6

    /// Bodies from the most recent frame that actually found any.
    private(set) var lastBodies: [BodyCandidate] = []
    private(set) var lastPublishedBody: BodyCandidate?
    private var frameCounter = 0
    private var lastBodiesSeen: TimeInterval = 0

    // MARK: - Processing

    /// Evaluates if body pose detection should run for the current frame.
    func shouldRunBodyPose(tracksSinglePlayer: Bool) -> Bool {
        let runs = tracksSinglePlayer && frameCounter % max(bodyPoseFrameInterval, 1) == 0
        frameCounter &+= 1
        return runs
    }

    /// Extracts body candidates from body pose observation results.
    ///
    /// An empty result does not immediately clear `lastBodies`: the previous
    /// bodies stand in until `bodyGracePeriod` lapses. The player has not
    /// actually left the room because one inference pass missed their
    /// shoulders, and dropping them instantly takes the hands down with them.
    @discardableResult
    func processObservations(
        _ observations: [VNHumanBodyPoseObservation]?,
        now: TimeInterval = CACurrentMediaTime()
    ) -> [BodyCandidate] {
        let candidates = (observations ?? []).compactMap {
            Self.bodyCandidate(from: $0, jointConfidenceThreshold: jointConfidenceThreshold)
        }

        if !candidates.isEmpty {
            lastBodies = candidates
            lastBodiesSeen = now
        } else if now - lastBodiesSeen > bodyGracePeriod {
            lastBodies = []
        }

        return lastBodies
    }

    /// Resolves the nearest player body from detected candidates.
    func resolvePlayer(from bodies: [BodyCandidate]) -> BodyCandidate? {
        Self.nearestBody(in: bodies).map { bodies[$0] }
    }

    // MARK: - Static Body Detection & Matching Utilities

    /// Reduces a Vision body observation to the upper body candidate.
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
            head: point(.nose) ?? point(.leftEar) ?? point(.rightEar),
            leftShoulder: leftShoulder,
            rightShoulder: rightShoulder,
            leftHip: point(.leftHip),
            rightHip: point(.rightHip),
            // Swapped on purpose: the capture connection mirrors the buffer
            // before Vision ever sees it, so Vision's own left/right wrist labels
            // come out anatomically backwards — what it calls the left wrist is
            // the player's actual right one.
            leftWrist: point(.rightWrist),
            rightWrist: point(.leftWrist)
        )
    }

    /// The body nearest the camera — the widest shoulders on screen.
    static func nearestBody(in bodies: [BodyCandidate]) -> Int? {
        bodies.indices
            .filter { bodies[$0].scale > 0 }
            .max { bodies[$0].scale < bodies[$1].scale }
    }

    /// Picks the hands belonging to the player, using the bodies Vision found
    /// in the same frame.
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

        func nearestWrist(of body: Int, to hand: CGPoint) -> CGFloat {
            bodies[body].wrists.map { $0.distance(to: hand) }.min() ?? .greatestFiniteMagnitude
        }

        let playerWrists: [CGPoint] = {
            guard let requiredHand else { return bodies[player].wrists }
            let wrist = requiredHand == .left ? bodies[player].leftWrist : bodies[player].rightWrist
            return wrist.map { [$0] } ?? []
        }()

        let matched: [(index: Int, distance: CGFloat)] = handWrists.indices.compactMap { index in
            let hand = handWrists[index]

            let toPlayer = playerWrists.map { $0.distance(to: hand) }.min() ?? .greatestFiniteMagnitude
            guard toPlayer <= reach else { return nil }

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
}

// MARK: - Private distance helper

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
