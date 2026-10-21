//
//  HandIdentityTracker.swift
//  PlayFeat
//
//  Turns each frame's hand readings into hands with stable IDs and a stable
//  left/right side. Vision reports hands in no particular order and misses
//  some frames entirely, so this:
//
//  - predicts where each known hand should be now from its recent velocity,
//    and matches readings to those predictions with the cheapest overall
//    assignment (not first-come-first-served, which swapped crossing hands);
//  - keeps a running left/right vote per hand from Vision's chirality and the
//    body's wrists, so one bad frame can't flip a side, and leaves the side
//    unknown rather than guessing when the evidence is thin;
//  - lets a missed hand coast at a bounded predicted position with falling
//    confidence for `gracePeriod`, and remembers its ID and side for
//    `identityMemory` so it comes back as itself.
//
//  Pure — readings and a timestamp in, hands out — so it can be tested by
//  feeding it made-up frames, without a camera.
//

import CoreGraphics
import Foundation

/// `nonisolated` so it can run on the camera's background queue: it is a plain
/// value with no shared state.
nonisolated struct HandIdentityTracker {

    /// One frame's reading of one hand, with the side evidence that came with it.
    struct Reading {
        let classification: HandClassifier.Classification
        /// The side the player's body pose puts this hand on — only on frames
        /// where the body was freshly measured, since stale wrists lag a
        /// moving hand.
        var bodySide: HandSide? = nil
    }

    // MARK: - Tuning
    //
    // `var` on purpose: hand size, camera distance and lighting all shift
    // these, so they are tuning knobs, not constants. Times are in seconds, so
    // they hold at any frame rate; distances are in normalized Vision units.

    /// Exponential smoothing applied to each cursor (0 = frozen, 1 = raw).
    var cursorSmoothing: CGFloat = 0.35

    /// How far a reading may be from a hand's *predicted* position and still
    /// continue that hand.
    var matchRadius: CGFloat = 0.45

    /// How long a missed hand stays published, coasting.
    var gracePeriod: TimeInterval = 0.35

    /// How long a missed hand's ID and side are remembered, so a hand that
    /// comes back after a longer gap is recognised rather than renamed.
    var identityMemory: TimeInterval = 1.0

    /// How far from where it was lost a remembered hand may reappear.
    var recoveryRadius: CGFloat = 0.6

    /// How close to a live hand's predicted position a reading must be to
    /// count as that hand continuing — used to keep a fast hand the body
    /// detector's slower wrists have fallen behind.
    var continuityRadius: CGFloat = 0.2

    /// Prediction never extrapolates further ahead than this, or at more
    /// than `maximumSpeed` (normalized units per second).
    var predictionHorizon: TimeInterval = 0.12
    var maximumSpeed: CGFloat = 4

    /// How much each kind of evidence moves a hand's side vote (−1…1).
    var chiralityVote: CGFloat = 0.15
    var bodySideVote: CGFloat = 0.35
    /// With two hands up and one side settled, the other leans the other way.
    var pairingVote: CGFloat = 0.1
    /// The vote has to pass this before a side is published.
    var sideCommitThreshold: CGFloat = 0.3

    /// Grabbing is a **pinch**: thumb tip and index-finger tip brought
    /// together. Pinched below `pinchCloseRatio`, apart above `pinchOpenRatio`;
    /// the gap between them stops the state flickering at the boundary.
    var pinchCloseRatio: CGFloat = 0.3
    var pinchOpenRatio: CGFloat = 0.5

    /// Penalties folded into matching costs.
    private let wrongSidePenalty: CGFloat = 0.2
    private let recoveryPenalty: CGFloat = 0.15
    /// More than any gated match can cost, so matching as many readings as
    /// possible always wins over a cheaper set of fewer matches.
    private static let unmatchedCost: CGFloat = 1

    // MARK: - State

    private var tracked: [TrackedHand] = []
    private var nextHandID = 0

    // MARK: - Update

    /// Matches this frame's readings to the hands already being tracked and
    /// returns every hand to publish, including ones coasting through a gap.
    /// Pass an empty array for a frame where Vision saw nothing.
    mutating func update(with readings: [Reading], at now: TimeInterval) -> [HandData] {
        tracked.removeAll { now - $0.lastSeen > identityMemory }

        let assignments = Self.bestAssignment(
            costs: readings.map { reading in tracked.map { cost(of: reading, for: $0, at: now) } },
            unmatchedCost: Self.unmatchedCost
        )

        var seenThisFrame = Set<Int>()
        for (index, reading) in readings.enumerated() {
            if let match = assignments[index] {
                tracked[match] = observed(tracked[match], reading: reading, at: now)
                seenThisFrame.insert(tracked[match].id)
            } else {
                let hand = newHand(from: reading, at: now)
                tracked.append(hand)
                seenThisFrame.insert(hand.id)
            }
        }

        for index in tracked.indices where !seenThisFrame.contains(tracked[index].id) {
            // A frame with no reading is no evidence either way, so a
            // half-built case for a pinch change is dropped, not resumed.
            tracked[index].pinch.clearEvidence()
        }
        leanUnsettledHand(seen: seenThisFrame)

        return publishedHands(at: now)
    }

    /// Whether `point` is where a hand already being followed should be now.
    ///
    /// Lets HandFrameProcessor keep a fast-moving hand that the body
    /// detector — run every few frames — has fallen behind, without opening
    /// the door to a stranger's hand appearing somewhere else.
    func continuesTrackedHand(at point: CGPoint, now: TimeInterval) -> Bool {
        tracked.contains { hand in
            let missing = now - hand.lastSeen
            return missing <= gracePeriod
                && Self.distance(point, hand.predictedPosition(after: missing, horizon: predictionHorizon))
                    <= continuityRadius
        }
    }

    // MARK: - Matching

    /// What it costs to call `reading` a continuation of `hand`, or nil when
    /// it can't be: too far from where the hand should be, or a remembered
    /// hand coming back as the other side.
    private func cost(of reading: Reading, for hand: TrackedHand, at now: TimeInterval) -> CGFloat? {
        let missing = now - hand.lastSeen
        let isLive = missing <= gracePeriod
        let predicted = hand.predictedPosition(after: missing, horizon: predictionHorizon)
        var cost = Self.distance(reading.classification.location, predicted)
        guard cost <= (isLive ? matchRadius : recoveryRadius) else { return nil }

        if let side = hand.side(threshold: sideCommitThreshold),
           let hint = reading.bodySide ?? reading.classification.side, hint != side {
            guard isLive else { return nil }
            cost += wrongSidePenalty
        }
        return isLive ? cost : cost + recoveryPenalty
    }

    /// For each reading, the index of the hand it continues — or nil for a
    /// new hand — chosen so the most readings are matched at the lowest total
    /// cost. `costs[reading][hand]` is nil where a match isn't allowed.
    ///
    /// Exhaustive, which is cheap at the two-to-four hands Vision is asked
    /// for, and unlike a greedy pass doesn't depend on which reading Vision
    /// happened to list first.
    static func bestAssignment(costs: [[CGFloat?]], unmatchedCost: CGFloat) -> [Int?] {
        var best: (total: CGFloat, assignment: [Int?]) = (.greatestFiniteMagnitude, [])
        var current = [Int?]()

        func search(_ reading: Int, total: CGFloat, claimed: Set<Int>) {
            guard total < best.total else { return }
            guard reading < costs.count else {
                best = (total, current)
                return
            }
            for (hand, cost) in costs[reading].enumerated() where !claimed.contains(hand) {
                guard let cost else { continue }
                current.append(hand)
                search(reading + 1, total: total + cost, claimed: claimed.union([hand]))
                current.removeLast()
            }
            current.append(nil)
            search(reading + 1, total: total + unmatchedCost, claimed: claimed)
            current.removeLast()
        }

        search(0, total: 0, claimed: [])
        return best.assignment
    }

    /// Position-only matching: each new position to the previous one it
    /// continues, within `radius`. Kept for the plain case and its tests.
    static func matchAssignments(
        newPositions: [CGPoint],
        previousPositions: [CGPoint],
        radius: CGFloat
    ) -> [Int?] {
        let costs = newPositions.map { new in
            previousPositions.map { previous -> CGFloat? in
                let distance = previous.distance(to: new)
                return distance < radius ? distance : nil
            }
        }
        return bestAssignment(costs: costs, unmatchedCost: radius * 2 + 1)
    }

    // MARK: - Hand updates

    private mutating func newHand(from reading: Reading, at now: TimeInterval) -> TrackedHand {
        var hand = TrackedHand(id: nextHandID, position: reading.classification.location,
                               smoothed: reading.classification.location,
                               skeleton: reading.classification.skeleton, lastSeen: now)
        nextHandID += 1
        hand.pinch.record(ratio: reading.classification.pinchRatio,
                          closeRatio: pinchCloseRatio, openRatio: pinchOpenRatio)
        hand.vote(sideEvidence(of: reading))
        return hand
    }

    /// `hand` updated with a fresh reading of it.
    private func observed(_ hand: TrackedHand, reading: Reading, at now: TimeInterval) -> TrackedHand {
        var hand = hand
        let location = reading.classification.location
        let elapsed = now - hand.lastSeen

        if elapsed > gracePeriod {
            // Back from a longer gap: whatever it was doing before is stale.
            // It keeps its name and side, nothing else.
            hand.velocity = .zero
            hand.smoothed = location
            hand.pinch = PinchDetector()
        } else {
            hand.velocity = blendedVelocity(of: hand, toward: location, over: elapsed)
            // Smooth the cursor: Vision's per-frame jitter is easily 20–30pt on
            // screen, enough to slide off an ingredient mid-grab.
            hand.smoothed = CGPoint(
                x: hand.smoothed.x + (location.x - hand.smoothed.x) * cursorSmoothing,
                y: hand.smoothed.y + (location.y - hand.smoothed.y) * cursorSmoothing
            )
        }
        hand.position = location
        hand.lastSeen = now
        hand.skeleton = reading.classification.skeleton
        // Evidence-based, and per hand, so neither one bad frame nor the
        // other hand can flip this one's state.
        hand.pinch.record(ratio: reading.classification.pinchRatio,
                          closeRatio: pinchCloseRatio, openRatio: pinchOpenRatio)
        hand.vote(sideEvidence(of: reading))
        return hand
    }

    /// Half the newest step, half the old estimate, capped at a plausible
    /// speed — enough to follow a fast chop, too little for one bad reading
    /// to fling the prediction across the frame.
    private func blendedVelocity(of hand: TrackedHand, toward location: CGPoint,
                                 over elapsed: TimeInterval) -> CGVector {
        let seconds = max(elapsed, 1.0 / 120)
        var step = CGVector(dx: (location.x - hand.position.x) / seconds,
                            dy: (location.y - hand.position.y) / seconds)
        let speed = hypot(step.dx, step.dy)
        if speed > maximumSpeed {
            step = CGVector(dx: step.dx / speed * maximumSpeed, dy: step.dy / speed * maximumSpeed)
        }
        return CGVector(dx: (step.dx + hand.velocity.dx) / 2, dy: (step.dy + hand.velocity.dy) / 2)
    }

    /// The left-positive vote this reading casts.
    private func sideEvidence(of reading: Reading) -> CGFloat {
        Self.vote(for: reading.classification.side, weight: chiralityVote)
            + Self.vote(for: reading.bodySide, weight: bodySideVote)
    }

    private static func vote(for side: HandSide?, weight: CGFloat) -> CGFloat {
        switch side {
        case .left: weight
        case .right: -weight
        case nil: 0
        }
    }

    /// Two hands in view, one of them settled: the other is presumably the
    /// other hand, so it leans that way — gently, so real evidence still wins.
    private mutating func leanUnsettledHand(seen: Set<Int>) {
        let visible = tracked.indices.filter { seen.contains(tracked[$0].id) }
        guard visible.count == 2 else { return }
        for (index, other) in [(visible[0], visible[1]), (visible[1], visible[0])] {
            guard tracked[index].side(threshold: sideCommitThreshold) == nil,
                  let settled = tracked[other].side(threshold: sideCommitThreshold) else { continue }
            tracked[index].vote(Self.vote(for: settled == .left ? .right : .left, weight: pairingVote))
        }
    }

    // MARK: - Publishing

    private func publishedHands(at now: TimeInterval) -> [HandData] {
        let live = tracked.filter { now - $0.lastSeen <= gracePeriod }
        return live.map { hand in
            var data = hand.published(at: now, gracePeriod: gracePeriod, horizon: predictionHorizon)
            data.side = exclusiveSide(of: hand, among: live)
            return data
        }
    }

    /// A hand's side, unless a hand with stronger evidence claims the same
    /// one — then it is published as unknown rather than as a duplicate.
    private func exclusiveSide(of hand: TrackedHand, among live: [TrackedHand]) -> HandSide? {
        guard let side = hand.side(threshold: sideCommitThreshold) else { return nil }
        let outranked = live.contains { other in
            other.id != hand.id && other.side(threshold: sideCommitThreshold) == side
                && (abs(other.sideScore), other.id) > (abs(hand.sideScore), hand.id)
        }
        return outranked ? nil : side
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}

// MARK: - Tracked hand

/// One hand as remembered between frames.
private nonisolated struct TrackedHand {
    let id: Int
    /// The latest raw reading — what matching and prediction start from.
    var position: CGPoint
    /// The published cursor, smoothed against Vision's jitter.
    var smoothed: CGPoint
    /// Normalized units per second.
    var velocity: CGVector = .zero
    /// Evidence-based pinch state — see `PinchDetector`.
    var pinch = PinchDetector()
    /// Last skeleton Vision gave for this hand, drawn while it coasts.
    var skeleton: [[CGPoint]]
    var lastSeen: TimeInterval
    /// Running side vote: positive leans left, negative right, within −1…1.
    var sideScore: CGFloat = 0

    func side(threshold: CGFloat) -> HandSide? {
        if sideScore >= threshold { return .left }
        if sideScore <= -threshold { return .right }
        return nil
    }

    mutating func vote(_ amount: CGFloat) {
        sideScore = min(max(sideScore + amount, -1), 1)
    }

    /// Where the hand should be after `missing` seconds unseen, extrapolating
    /// no further than `horizon` so a long gap doesn't send it off screen.
    func predictedPosition(after missing: TimeInterval, horizon: TimeInterval) -> CGPoint {
        position.offset(by: velocity, for: min(max(missing, 0), horizon))
    }

    func published(at now: TimeInterval, gracePeriod: TimeInterval, horizon: TimeInterval) -> HandData {
        let missing = now - lastSeen
        let isPredicted = missing > 0
        return HandData(
            id: id,
            cursorPosition: isPredicted ? smoothed.offset(by: velocity, for: min(missing, horizon)) : smoothed,
            isOpenHand: !pinch.isPinching,
            isClosedFist: pinch.isPinching,
            skeleton: skeleton,
            isPredicted: isPredicted,
            trackingConfidence: isPredicted ? max(0, 1 - CGFloat(missing / gracePeriod)) : 1
        )
    }
}

private nonisolated extension CGPoint {
    func offset(by velocity: CGVector, for seconds: TimeInterval) -> CGPoint {
        CGPoint(x: x + velocity.dx * seconds, y: y + velocity.dy * seconds)
    }
}
