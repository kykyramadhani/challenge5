//
//  HandIdentityTracker.swift
//  PlayFeat
//
//  Turns each frame's hand readings into hands with stable IDs. Vision
//  reports hands in no particular order, so this matches every reading to the
//  hand it most likely continues, smooths its cursor, keeps its pinch state,
//  and lets a hand coast through a few dropped frames instead of vanishing.
//
//  Pure — readings and a timestamp in, hands out — so the whole thing can be
//  tested by feeding it made-up frames, without a camera.
//

// Possible Changes
// 1. There are possiblePinch/possibleApart states that are used to smooth out state transitions. 
//
//

import CoreGraphics
import Foundation

/// `nonisolated` so it can run on the camera's background queue: it is a plain
/// value with no shared state.
nonisolated struct HandIdentityTracker {
    // MARK: - Tuning
    //
    // `var` on purpose: hand size, camera distance and lighting all shift
    // these, so they are tuning knobs, not constants.

    /// Exponential smoothing applied to each cursor (0 = frozen, 1 = raw).
    var cursorSmoothing: CGFloat = 0.35

    /// How far (in normalized units) a hand may travel between frames and still
    /// be considered the same hand.
    var matchRadius: CGFloat = 0.45

    /// How long a hand's trajectory survives after Vision stops reporting it.
    var gracePeriod: TimeInterval = 0.35

    /// Grabbing is a **pinch**: thumb tip and index-finger tip brought
    /// together. Pinched below `pinchCloseRatio`, apart above `pinchOpenRatio`;
    /// the gap between them stops the state flickering at the boundary.
    var pinchCloseRatio: CGFloat = 0.3
    var pinchOpenRatio: CGFloat = 0.5

    // MARK: - State

    /// One hand as remembered between frames.
    private struct TrackedHand {
        let id: Int
        var smoothed: CGPoint
        /// Evidence-based pinch state — see `PinchDetector`.
        var pinch: PinchDetector
        /// Last skeleton Vision gave for this hand. Kept so a hand that is
        /// coasting through a dropped frame can still be drawn where it was,
        /// rather than blinking out.
        var skeleton: [[CGPoint]]
        /// Last time Vision actually reported this hand; drives the grace period.
        var lastSeen: TimeInterval

        var published: HandData {
            HandData(
                id: id,
                cursorPosition: smoothed,
                isOpenHand: !pinch.isPinching,
                isClosedFist: pinch.isPinching,
                skeleton: skeleton
            )
        }
    }

    private var tracked: [TrackedHand] = []
    private var nextHandID = 0

    // MARK: - Update

    /// Matches this frame's readings to the hands already being tracked and
    /// returns every hand to publish, including ones coasting through a
    /// dropped frame. Pass an empty array for a frame where Vision saw nothing.
    ///
    /// Vision hands back observations in no particular order, so without the
    /// matching the two hands would trade identities at random — and with them,
    /// whatever each was dragging.
    mutating func update(
        with readings: [HandClassifier.Classification],
        at now: TimeInterval
    ) -> [HandData] {

        let assignments = Self.matchAssignments(
            newPositions: readings.map(\.location),
            previousPositions: tracked.map(\.smoothed),
            radius: matchRadius
        )

        var stillTracked: [TrackedHand] = []

        for (index, reading) in readings.enumerated() {
            var hand: TrackedHand

            // Check if this reading continues a previously tracked hand, or is a new hand.
            if let previous = assignments[index] {
                hand = tracked[previous]
            } else {
                hand = TrackedHand(id: nextHandID, smoothed: reading.location,
                                   pinch: PinchDetector(), skeleton: reading.skeleton,
                                   lastSeen: now)
                nextHandID += 1
            }
            hand.lastSeen = now
            hand.skeleton = reading.skeleton

            // Smooth the cursor: Vision's per-frame jitter is easily 20–30pt on
            // screen, enough to slide off an ingredient mid-grab.
            hand.smoothed = CGPoint(
                x: hand.smoothed.x + (reading.location.x - hand.smoothed.x) * cursorSmoothing,
                y: hand.smoothed.y + (reading.location.y - hand.smoothed.y) * cursorSmoothing
            )

            // Evidence-based, and per hand, so neither one bad frame nor the
            // other hand can flip this one's state.
            hand.pinch.record(
                ratio: reading.pinchRatio,
                closeRatio: pinchCloseRatio,
                openRatio: pinchOpenRatio
            )

            stillTracked.append(hand)
        }

        // Hands Vision didn't report this frame keep *coasting*: they stay
        // tracked and stay published, sitting at their last known position,
        // until the grace period lapses.
        //
        // Publishing them is the point. Reporting only what Vision saw this
        // exact frame is what made the aura strobe — hand pose regularly drops
        // a frame to motion blur or a turned palm, and every one of those was
        // being handed downstream as "the hand is gone".
        let matched = Set(assignments.compactMap { $0 })
        for (index, previous) in tracked.enumerated()
        where !matched.contains(index) && now - previous.lastSeen <= gracePeriod {
            var coasting = previous
            // A frame with no reading is no evidence either way, so the
            // half-built case for a state change is discarded rather than
            // resumed against a newer, contradicting run of frames.
            coasting.pinch.clearEvidence()
            stillTracked.append(coasting)
        }

        tracked = stillTracked
        return stillTracked.map(\.published)
    }

    // MARK: - Matching

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
                let distance = hypot(position.x - previous.x, position.y - previous.y)
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
}
