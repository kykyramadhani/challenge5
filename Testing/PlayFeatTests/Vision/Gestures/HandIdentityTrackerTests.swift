//
//  HandIdentityTrackerTests.swift
//  PlayFeatTests
//
//  The frame-to-frame rules of HandIdentityTracker: IDs that stick, the grace
//  period that lets a hand coast through dropped frames, cursor smoothing and
//  the pinch needing several frames to commit. Fed made-up readings, so no
//  camera is involved.
//

import Testing
import CoreGraphics
@testable import PlayFeat

struct HandIdentityTrackerTests {

    /// One frame's reading for a hand at `point`. `pinch` is the thumb-to-index
    /// gap in palm lengths: 1.0 is wide open, 0.1 is pinched.
    private func reading(at point: CGPoint, pinch: CGFloat = 1.0) -> HandClassifier.Classification {
        HandClassifier.Classification(
            location: point,
            wrist: point,
            palmLength: 0.1,
            pinchRatio: pinch,
            skeleton: []
        )
    }

    private let centre = CGPoint(x: 0.5, y: 0.5)

    // MARK: - Identity

    @Test func aHandKeepsItsIDFromFrameToFrame() {
        var tracker = HandIdentityTracker()

        let first = tracker.update(with: [reading(at: centre)], at: 0)
        let second = tracker.update(with: [reading(at: CGPoint(x: 0.52, y: 0.5))], at: 0.033)

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

    // MARK: - Grace period

    /// Vision regularly drops a frame to motion blur. The hand must stay on
    /// screen, where it was, or the aura strobes and a grab can let go.
    @Test func aHandMissingForOneFrameIsStillPublished() {
        var tracker = HandIdentityTracker()
        _ = tracker.update(with: [reading(at: centre)], at: 0)

        let hands = tracker.update(with: [], at: 0.1)

        #expect(hands.map(\.id) == [0])
        #expect(hands.first?.cursorPosition == centre)
    }

    @Test func aHandMissingLongerThanTheGracePeriodGoesAway() {
        var tracker = HandIdentityTracker()
        _ = tracker.update(with: [reading(at: centre)], at: 0)

        let hands = tracker.update(with: [], at: tracker.gracePeriod + 0.1)

        #expect(hands.isEmpty)
    }

    /// Once a hand has been dropped, the next one seen is a new hand — it must
    /// not inherit an ID (and with it, whatever the old hand was holding).
    @Test func aHandSeenAgainAfterTheGracePeriodIsANewHand() {
        var tracker = HandIdentityTracker()
        _ = tracker.update(with: [reading(at: centre)], at: 0)
        _ = tracker.update(with: [], at: tracker.gracePeriod + 0.1)

        let hands = tracker.update(with: [reading(at: centre)], at: tracker.gracePeriod + 0.2)

        #expect(hands.map(\.id) == [1])
    }

    // MARK: - Smoothing

    /// The cursor moves only part of the way toward each new reading, which is
    /// what keeps Vision's jitter from sliding the hand off an ingredient.
    @Test func theCursorMovesPartWayTowardANewReading() {
        var tracker = HandIdentityTracker()
        _ = tracker.update(with: [reading(at: centre)], at: 0)

        let hands = tracker.update(with: [reading(at: CGPoint(x: 0.6, y: 0.5))], at: 0.033)

        let expectedX = 0.5 + 0.1 * tracker.cursorSmoothing
        let x = hands.first?.cursorPosition.x ?? 0
        #expect(abs(x - expectedX) < 0.0001)
    }

    // MARK: - Pinch

    /// One pinched frame is not a grab; a short run of them is.
    @Test func aPinchCommitsOnlyAfterSeveralFrames() {
        var tracker = HandIdentityTracker()

        let afterOne = tracker.update(with: [reading(at: centre, pinch: 0.1)], at: 0)
        _ = tracker.update(with: [reading(at: centre, pinch: 0.1)], at: 0.033)
        let afterThree = tracker.update(with: [reading(at: centre, pinch: 0.1)], at: 0.066)

        #expect(afterOne.first?.isClosedFist == false)
        #expect(afterThree.first?.isClosedFist == true)
    }
}
