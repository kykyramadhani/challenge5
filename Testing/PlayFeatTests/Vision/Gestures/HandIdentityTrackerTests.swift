//
//  HandIdentityTrackerTests.swift
//  PlayFeatTests
//
//  The frame-to-frame rules of HandIdentityTracker: IDs that stick through
//  reordering, crossing and fast moves; left/right sides that need real
//  evidence and never duplicate; coasting through gaps on a bounded
//  prediction; recovering a hand that comes back; smoothing and the pinch.
//  Fed made-up readings, so no camera is involved.
//

import Testing
import CoreGraphics
@testable import PlayFeat

struct HandIdentityTrackerTests {

    /// One frame's reading for a hand at `point`. `pinch` is the thumb-to-index
    /// gap in palm lengths: 1.0 is wide open, 0.1 is pinched.
    private func reading(
        at point: CGPoint,
        pinch: CGFloat = 1.0,
        chirality: HandSide? = nil,
        body: HandSide? = nil
    ) -> HandIdentityTracker.Reading {
        HandIdentityTracker.Reading(
            classification: HandClassifier.Classification(
                location: point, wrist: point, palmLength: 0.1, pinchRatio: pinch,
                skeleton: [], side: chirality
            ),
            bodySide: body
        )
    }

    private let centre = CGPoint(x: 0.5, y: 0.5)
    private let frame = 1.0 / 30

    private func id(of side: HandSide, in hands: [HandData]) -> Int? {
        hands.first { $0.side == side }?.id
    }

    // MARK: - Identity

    @Test func aHandKeepsItsIDFromFrameToFrame() {
        var tracker = HandIdentityTracker()

        let first = tracker.update(with: [reading(at: centre)], at: 0)
        let second = tracker.update(with: [reading(at: CGPoint(x: 0.52, y: 0.5))], at: frame)

        #expect(first.map(\.id) == [0])
        #expect(second.map(\.id) == [0])
    }

    @Test func twoHandsGetDifferentIDs() {
        var tracker = HandIdentityTracker()

        let hands = tracker.update(
            with: [reading(at: CGPoint(x: 0.2, y: 0.5)), reading(at: CGPoint(x: 0.8, y: 0.5))],
            at: 0
        )

        #expect(Set(hands.map(\.id)) == [0, 1])
    }

    /// Vision lists hands in any order. Swapping the order every frame must
    /// not swap the IDs.
    @Test func readingOrderNeverSwapsIDs() {
        var tracker = HandIdentityTracker()
        let a = CGPoint(x: 0.3, y: 0.5), b = CGPoint(x: 0.7, y: 0.5)
        let start = tracker.update(with: [reading(at: a), reading(at: b)], at: 0)
        let idAtA = start.first { $0.cursorPosition == a }?.id

        for step in 1...10 {
            let readings = [reading(at: a), reading(at: b)]
            let hands = tracker.update(with: step.isMultiple(of: 2) ? readings : readings.reversed(),
                                       at: Double(step) * frame)
            let nearestA = hands.min { abs($0.cursorPosition.x - a.x) < abs($1.cursorPosition.x - a.x) }
            #expect(nearestA?.id == idAtA)
        }
    }

    /// Crossing hands pass close to each other; following each one's motion
    /// keeps them apart instead of trading names at the crossing.
    @Test func crossingHandsKeepTheirIdentities() {
        var tracker = HandIdentityTracker()
        var leftID: Int?
        var rightID: Int?

        // Left hand sweeps 0.2 → 0.8 while the right sweeps 0.8 → 0.2, at
        // slightly different heights, as crossing arms do.
        for step in 0...30 {
            let t = CGFloat(step) / 30
            let leftHand = CGPoint(x: 0.2 + 0.6 * t, y: 0.45)
            let rightHand = CGPoint(x: 0.8 - 0.6 * t, y: 0.55)
            let hands = tracker.update(with: [reading(at: rightHand), reading(at: leftHand)],
                                       at: Double(step) * frame)
            let movingRight = hands.min { abs($0.cursorPosition.y - 0.45) < abs($1.cursorPosition.y - 0.45) }
            let movingLeft = hands.min { abs($0.cursorPosition.y - 0.55) < abs($1.cursorPosition.y - 0.55) }
            if step == 0 {
                leftID = movingRight?.id
                rightID = movingLeft?.id
            }
            #expect(movingRight?.id == leftID)
            #expect(movingLeft?.id == rightID)
        }
    }

    /// A fast hand jumps a long way per frame. Matching against where it is
    /// heading, not where the smoothed cursor lags, keeps it the same hand.
    @Test func aFastHandKeepsItsID() {
        var tracker = HandIdentityTracker()
        tracker.matchRadius = 0.12

        for step in 0...8 {
            let hands = tracker.update(with: [reading(at: CGPoint(x: 0.1 + 0.1 * CGFloat(step), y: 0.5))],
                                       at: Double(step) * frame)
            #expect(hands.map(\.id) == [0])
        }
    }

    /// Matching picks the cheapest overall assignment, not first come first
    /// served: here a greedy pass would let the first reading steal the
    /// second's hand and leave one hand renamed.
    @Test func matchingIsGloballyBestNotGreedy() {
        let assignments = HandIdentityTracker.matchAssignments(
            newPositions: [CGPoint(x: 0.2, y: 0.5), CGPoint(x: 0.45, y: 0.5)],
            previousPositions: [CGPoint(x: 0.0, y: 0.5), CGPoint(x: 0.3, y: 0.5)],
            radius: 0.28
        )
        #expect(assignments == [0, 1])
    }

    // MARK: - Sides

    @Test func theBodysWristSettlesASideAtOnce() {
        var tracker = HandIdentityTracker()
        let hands = tracker.update(with: [reading(at: centre, body: .left)], at: 0)
        #expect(hands.first?.side == .left)
    }

    /// A single chirality reading is too weak to name a hand; it stays unknown
    /// rather than guessed.
    @Test func thinEvidenceLeavesTheSideUnknown() {
        var tracker = HandIdentityTracker()
        let hands = tracker.update(with: [reading(at: centre, chirality: .right)], at: 0)
        #expect(hands.first?.side == nil)
    }

    /// Chirality flickers. One contrary frame must not flip a settled hand.
    @Test func oneContraryReadingDoesNotFlipASide() {
        var tracker = HandIdentityTracker()
        _ = tracker.update(with: [reading(at: centre, body: .left)], at: 0)
        _ = tracker.update(with: [reading(at: centre, chirality: .left)], at: frame)

        let hands = tracker.update(with: [reading(at: centre, chirality: .right)], at: 2 * frame)

        #expect(hands.first?.side == .left)
    }

    /// Two hands are never both published as the same side: the one with the
    /// weaker case is reported as unknown instead.
    @Test func twoHandsNeverShareASide() {
        var tracker = HandIdentityTracker()
        let hands = tracker.update(with: [
            reading(at: CGPoint(x: 0.3, y: 0.5), body: .left),
            reading(at: CGPoint(x: 0.7, y: 0.5), chirality: .left, body: .left),
        ], at: 0)

        #expect(hands.filter { $0.side == .left }.count == 1)
        #expect(hands.contains { $0.side == nil })
    }

    /// Sides follow the hands, not the screen: after crossing, the left hand
    /// is still the left hand.
    @Test func sidesSurviveCrossing() {
        var tracker = HandIdentityTracker()
        _ = tracker.update(with: [reading(at: CGPoint(x: 0.2, y: 0.45), body: .left),
                                  reading(at: CGPoint(x: 0.8, y: 0.55), body: .right)], at: 0)
        var hands: [HandData] = []
        for step in 1...30 {
            let t = CGFloat(step) / 30
            hands = tracker.update(with: [reading(at: CGPoint(x: 0.2 + 0.6 * t, y: 0.45)),
                                          reading(at: CGPoint(x: 0.8 - 0.6 * t, y: 0.55))],
                                   at: Double(step) * frame)
        }
        let left = hands.first { $0.side == .left }
        #expect(left.map { $0.cursorPosition.x > 0.6 } == true, "the left hand ended up on the right")
    }

    // MARK: - Gaps

    /// Vision regularly drops a frame to motion blur. The hand must stay on
    /// screen, flagged as predicted so nothing acts on it.
    @Test func aHandMissingForOneFrameCoastsAsPredicted() {
        var tracker = HandIdentityTracker()
        _ = tracker.update(with: [reading(at: centre)], at: 0)

        let hands = tracker.update(with: [], at: 0.1)

        #expect(hands.map(\.id) == [0])
        #expect(hands.first?.cursorPosition == centre)
        #expect(hands.first?.isPredicted == true)
        #expect((hands.first?.trackingConfidence ?? 1) < 1)
    }

    /// A moving hand coasts along its path, but only so far.
    @Test func predictionFollowsVelocityButIsBounded() {
        var tracker = HandIdentityTracker()
        for step in 0...3 {
            _ = tracker.update(with: [reading(at: CGPoint(x: 0.3 + 0.03 * CGFloat(step), y: 0.5))],
                               at: Double(step) * frame)
        }
        let lastSeenX = tracker.update(with: [], at: 3 * frame).first?.cursorPosition.x ?? 0
        let shortGap = tracker.update(with: [], at: 3 * frame + 0.05).first?.cursorPosition.x ?? 0
        let longGap = tracker.update(with: [], at: 3 * frame + 0.3).first?.cursorPosition.x ?? 0

        #expect(shortGap > lastSeenX)
        #expect(longGap - lastSeenX <= tracker.maximumSpeed * tracker.predictionHorizon + 0.0001)
    }

    @Test func aHandMissingLongerThanTheGracePeriodIsNoLongerPublished() {
        var tracker = HandIdentityTracker()
        _ = tracker.update(with: [reading(at: centre)], at: 0)

        let hands = tracker.update(with: [], at: tracker.gracePeriod + 0.1)

        #expect(hands.isEmpty)
    }

    /// A hand that drops out and comes back within the identity memory is
    /// recognised: same ID, same side.
    @Test func aHandThatComesBackKeepsItsIDAndSide() {
        var tracker = HandIdentityTracker()
        _ = tracker.update(with: [reading(at: centre, body: .right)], at: 0)
        _ = tracker.update(with: [], at: tracker.gracePeriod + 0.1)

        let hands = tracker.update(with: [reading(at: CGPoint(x: 0.55, y: 0.5))], at: tracker.gracePeriod + 0.2)

        #expect(hands.map(\.id) == [0])
        #expect(hands.first?.side == .right)
        #expect(hands.first?.isPredicted == false)
    }

    /// After the memory runs out, the next hand seen is a new hand.
    @Test func aHandGoneLongerThanTheMemoryIsANewHand() {
        var tracker = HandIdentityTracker()
        _ = tracker.update(with: [reading(at: centre)], at: 0)
        _ = tracker.update(with: [], at: tracker.identityMemory + 0.1)

        let hands = tracker.update(with: [reading(at: centre)], at: tracker.identityMemory + 0.2)

        #expect(hands.map(\.id) == [1])
    }

    /// A remembered hand never comes back as the other side.
    @Test func aRememberedHandIsNotRecoveredAsTheOtherSide() {
        var tracker = HandIdentityTracker()
        _ = tracker.update(with: [reading(at: centre, body: .right)], at: 0)
        _ = tracker.update(with: [], at: tracker.gracePeriod + 0.1)

        let hands = tracker.update(with: [reading(at: centre, body: .left)], at: tracker.gracePeriod + 0.2)

        #expect(hands.map(\.id) == [1])
    }

    @Test func continuityIsJudgedFromThePredictedPosition() {
        var tracker = HandIdentityTracker()
        _ = tracker.update(with: [reading(at: centre)], at: 0)

        #expect(tracker.continuesTrackedHand(at: CGPoint(x: 0.55, y: 0.5), now: frame))
        #expect(!tracker.continuesTrackedHand(at: CGPoint(x: 0.95, y: 0.5), now: frame))
    }

    // MARK: - Smoothing

    /// The cursor moves only part of the way toward each new reading, which is
    /// what keeps Vision's jitter from sliding the hand off an ingredient.
    @Test func theCursorMovesPartWayTowardANewReading() {
        var tracker = HandIdentityTracker()
        _ = tracker.update(with: [reading(at: centre)], at: 0)

        let hands = tracker.update(with: [reading(at: CGPoint(x: 0.6, y: 0.5))], at: frame)

        let expectedX = 0.5 + 0.1 * tracker.cursorSmoothing
        let x = hands.first?.cursorPosition.x ?? 0
        #expect(abs(x - expectedX) < 0.0001)
    }

    // MARK: - Pinch

    /// One pinched frame is not a grab; a short run of them is.
    @Test func aPinchCommitsOnlyAfterSeveralFrames() {
        var tracker = HandIdentityTracker()

        let afterOne = tracker.update(with: [reading(at: centre, pinch: 0.1)], at: 0)
        _ = tracker.update(with: [reading(at: centre, pinch: 0.1)], at: frame)
        let afterThree = tracker.update(with: [reading(at: centre, pinch: 0.1)], at: 2 * frame)

        #expect(afterOne.first?.isClosedFist == false)
        #expect(afterThree.first?.isClosedFist == true)
    }
}
