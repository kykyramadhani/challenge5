//
//  HoverDetector.swift
//  GetCooking
//

import CoreGraphics
import Foundation

/// Fires once the player has held a hand over a target for `dwellDuration`.
///
/// Kept out of `GameScene` so the dwell and re-arm rules can be exercised
/// without a live SpriteKit view.
struct HoverDetector {
    /// How long the hand must stay put before the gesture fires.
    var dwellDuration: TimeInterval = 1.0

    /// Largest gap between two frames that still counts toward the dwell.
    ///
    /// Pausing stops SpriteKit calling `update(_:)` at all, so on resume `now`
    /// has jumped seconds ahead. Without this cap, a hand left resting over the
    /// bin across a pause would have its dwell completed for it the instant
    /// play resumed.
    var maxFrameGap: TimeInterval = 0.25

    /// How far through the current dwell, 0...1. Drives the progress ring —
    /// a silent two-second wait with nothing on screen reads as a broken
    /// gesture rather than a deliberate one.
    var progress: CGFloat {
        guard dwellDuration > 0 else { return 0 }
        return min(CGFloat(elapsed / dwellDuration), 1)
    }

    private var elapsed: TimeInterval = 0
    private var lastUpdate: TimeInterval?

    /// Set when the gesture fires, cleared once the hand leaves, so a hand
    /// parked on the target fires once instead of every frame.
    private var hasFired = false

    /// Forgets any dwell in progress — the hand left, or play stopped.
    mutating func reset() {
        elapsed = 0
        lastUpdate = nil
        hasFired = false
    }

    /// True on the single frame the dwell completes.
    mutating func update(isHovering: Bool, now: TimeInterval) -> Bool {
        guard isHovering else {
            reset()
            return false
        }

        // First frame of a hover contributes nothing, so a completed dwell is
        // exactly `dwellDuration` of wall clock from the frame it started on.
        let delta = lastUpdate.map { min(max(0, now - $0), maxFrameGap) } ?? 0
        lastUpdate = now

        guard !hasFired else { return false }

        elapsed += delta
        guard elapsed >= dwellDuration else { return false }

        hasFired = true
        elapsed = 0
        return true
    }
}
