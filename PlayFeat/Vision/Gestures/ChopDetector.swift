//
//  ChopDetector.swift
//  PlayFeat
//
//  Counts chops from the alternating heights of the player's two hands, as
//  in a handshake: left up and right down, then left down and right up, is
//  one chop; back again is the next. Speed and path don't matter, only that
//  the pair really swapped sides of the reference line.
//
//  Works in view space, where y grows *downward*: "up" is a smaller y. Pure,
//  so every rule below is unit-tested without a camera.
//

import CoreGraphics

nonisolated struct ChopDetector {

    /// One hand's height relative to the reference line.
    enum Height: Equatable {
        case up, down
    }

    /// The two poses a chop alternates between.
    enum Pose: Equatable {
        case leftUpRightDown
        case leftDownRightUp
    }

    /// What one observation did, and why — for the cutting progress and for
    /// the tracking diagnostics.
    enum Verdict: Equatable {
        /// A real alternation: exactly one chop.
        case chop(from: Pose, to: Pose)
        /// The first clear pose after a reset; the next opposite pose chops.
        case armed(Pose)
        /// Still in the pose that was last counted.
        case holding(Pose)
        /// Nothing counted, and why.
        case rejected(Reason)
    }

    enum Reason: Equatable {
        /// A hand the gesture needs isn't tracked at all (sequence reset).
        case handMissing
        /// A hand is coasting on a prediction, or its side isn't certain:
        /// gesture paused, nothing reset.
        case handUnreliable
        /// Both hands up or both down: not a chop pose.
        case sameHeight
        /// A hand is inside the dead band and hasn't picked a side yet.
        case heightUndecided
    }

    /// One hand as the detector sees it.
    struct HandSample {
        /// View space, y down.
        let y: CGFloat
        /// Seen this frame with a known side — see `HandData.isReliablyIdentified`.
        let isReliable: Bool
    }

    /// The line the hands alternate across, in view space.
    let referenceY: CGFloat
    /// Half the dead band around it. A hand has to clear the band to change
    /// height, which is what stops a hand hovering on the line from
    /// chattering between up and down.
    let deadBand: CGFloat

    private(set) var leftHeight: Height?
    private(set) var rightHeight: Height?
    /// The pose last counted (or armed); the next chop must be the other one.
    private(set) var lastPose: Pose?

    init(referenceY: CGFloat, deadBand: CGFloat) {
        self.referenceY = referenceY
        self.deadBand = max(0, deadBand)
    }

    /// Feeds one frame's hands in. Returns `.chop` at most once per real
    /// alternation, however many frames the hands then stay put.
    mutating func observe(left: HandSample?, right: HandSample?) -> Verdict {
        guard let left, let right else {
            // Gone past the tracker's grace period: whatever pose was built
            // up is stale, and must not pair with a pose seen after the hand
            // comes back.
            reset()
            return .rejected(.handMissing)
        }
        // Coasting or unidentified: hold everything, count nothing, and pick
        // up where we were once real readings return.
        guard left.isReliable, right.isReliable else { return .rejected(.handUnreliable) }

        leftHeight = height(at: left.y, was: leftHeight)
        rightHeight = height(at: right.y, was: rightHeight)
        guard let leftHeight, let rightHeight else { return .rejected(.heightUndecided) }

        guard let pose = Self.pose(left: leftHeight, right: rightHeight) else {
            return .rejected(.sameHeight)
        }
        return settle(on: pose)
    }

    /// One-hand mode: the one hand the player plays with, going up and down
    /// across the line, stands in for the pair — up counts as the
    /// left-up pose, down as left-down — so the same alternation rule applies.
    mutating func observe(hand: HandSample?) -> Verdict {
        guard let hand else {
            reset()
            return .rejected(.handMissing)
        }
        guard hand.isReliable else { return .rejected(.handUnreliable) }

        leftHeight = height(at: hand.y, was: leftHeight)
        guard let leftHeight else { return .rejected(.heightUndecided) }
        return settle(on: leftHeight == .up ? .leftUpRightDown : .leftDownRightUp)
    }

    mutating func reset() {
        leftHeight = nil
        rightHeight = nil
        lastPose = nil
    }

    // MARK: - Rules

    /// Hysteresis: up only once clearly above the band, down only once
    /// clearly below it, and otherwise whatever it was.
    private func height(at y: CGFloat, was previous: Height?) -> Height? {
        if y < referenceY - deadBand { return .up }
        if y > referenceY + deadBand { return .down }
        return previous
    }

    private static func pose(left: Height, right: Height) -> Pose? {
        switch (left, right) {
        case (.up, .down): .leftUpRightDown
        case (.down, .up): .leftDownRightUp
        default: nil
        }
    }

    private mutating func settle(on pose: Pose) -> Verdict {
        defer { lastPose = pose }
        guard let lastPose else { return .armed(pose) }
        return lastPose == pose ? .holding(pose) : .chop(from: lastPose, to: pose)
    }
}
