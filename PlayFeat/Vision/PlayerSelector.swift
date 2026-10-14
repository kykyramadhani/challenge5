//
//  PlayerSelector.swift
//  PlayFeat
//
//  Decides which of the bodies Vision found is the player. Until seat
//  calibration passes, that is whoever sits in the calibration frame; from
//  then on it is the person who calibrated, followed by position, and nobody
//  else in the room can take over.
//

import AVFoundation
import CoreGraphics

nonisolated struct PlayerSelector: Sendable {
    typealias BodyCandidate = HumanBodyPoseManager.BodyCandidate

    // MARK: - Types

    /// The seat calibration frame, so the person who calibrates is the one
    /// actually sitting in the box.
    struct Zone: Equatable, Sendable {
        /// The frame on screen, in view space (origin top-left).
        let frame: CGRect
        /// Size of the view `frame` was laid out in.
        let viewSize: CGSize
        /// How the preview fits the feed to that view.
        let gravity: AVLayerVideoGravity

        /// Judged by the chest rather than the hands, so it holds whatever
        /// the arms are doing.
        func contains(_ body: BodyCandidate, bufferSize: CGSize) -> Bool {
            let mapping = CameraViewMapping(bufferSize: bufferSize, gravity: gravity)
            return frame.contains(mapping.viewPoint(body.chest, in: viewSize))
        }
    }

    /// Where the locked player was last seen, in normalized Vision space.
    struct Anchor: Equatable, Sendable {
        let chest: CGPoint
        /// Shoulder span when last seen: the yardstick for how far the player
        /// may move between two body detections.
        let span: CGFloat

        init(_ body: BodyCandidate) {
            chest = body.chest
            span = body.scale
        }

        func distance(to body: BodyCandidate) -> CGFloat {
            hypot(body.chest.x - chest.x, body.chest.y - chest.y)
        }
    }

    // MARK: - State

    /// Set by the calibration screen; only consulted until the lock.
    var zone: Zone?

    /// The calibrated player. Nil until calibration passes.
    private(set) var anchor: Anchor?

    /// How far the player's chest may move between two body detections and
    /// still be the player, as a multiple of their shoulder span. Body pose
    /// runs a few times a second, so this only has to cover a lean, not a walk.
    var followTolerance: CGFloat = 0.5

    var isLocked: Bool { anchor != nil }

    // MARK: - Commands

    /// From now on only `body`'s owner is the player.
    mutating func lock(onto body: BodyCandidate) {
        anchor = Anchor(body)
    }

    /// Moves the anchor to where the locked player is now, so they can shift
    /// in their seat during a run. Ignored before the lock.
    mutating func follow(_ body: BodyCandidate) {
        guard isLocked else { return }
        anchor = Anchor(body)
    }

    /// Finds the player among `bodies` and moves the lock to where they are
    /// now, so it keeps up as they shift in their seat. Returns their index,
    /// or nil when the player isn't there.
    ///
    /// Both a command and a query on purpose: following must use the very
    /// body that was just picked, so the two steps never run apart.
    mutating func trackPlayer(in bodies: [BodyCandidate], bufferSize: CGSize) -> Int? {
        let player = playerIndex(in: bodies, bufferSize: bufferSize)
        if let player { follow(bodies[player]) }
        return player
    }

    /// Back to picking whoever sits in the calibration frame.
    mutating func reset() {
        zone = nil
        anchor = nil
    }

    // MARK: - Queries

    /// Index of the player among `bodies`, or nil when the player isn't there.
    func playerIndex(in bodies: [BodyCandidate], bufferSize: CGSize) -> Int? {
        if let anchor {
            return Self.index(in: bodies, nearest: anchor, tolerance: followTolerance)
        }
        return bodies.firstIndex { body in
            body.scale > 0 && (zone?.contains(body, bufferSize: bufferSize) ?? true)
        }
    }

    /// The body closest to `anchor`, if any is close enough to be the same
    /// person. Everyone further away is ignored, however big or central.
    static func index(
        in bodies: [BodyCandidate],
        nearest anchor: Anchor,
        tolerance: CGFloat
    ) -> Int? {
        let reach = anchor.span * tolerance
        return bodies.indices
            .filter { anchor.distance(to: bodies[$0]) <= reach }
            .min { anchor.distance(to: bodies[$0]) < anchor.distance(to: bodies[$1]) }
    }
}
