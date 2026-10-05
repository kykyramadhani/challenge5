//
//  PinchDetectorTests.swift
//  PlayFeatTests
//
//  Split out of GetCookingTests.swift (created by Kyky on 11/08/26).
//

import Testing
import Foundation
import CoreGraphics
@testable import PlayFeat

/// The evidence-counter pinch state machine. This is the thing that stops one
/// bad frame from dropping what the player is holding.
struct PinchDetectorTests {

    private let close: CGFloat = 0.3
    private let open: CGFloat = 0.5

    /// Feeds the same reading in `times` times.
    private func feed(
        _ detector: inout PinchDetector,
        ratio: CGFloat?,
        times: Int
    ) {
        for _ in 0..<times {
            detector.record(ratio: ratio, closeRatio: close, openRatio: open)
        }
    }

    /// One pinched frame is not enough — it takes a run of them.
    @Test func aSingleFrameDoesNotCommitAPinch() {
        var detector = PinchDetector(framesToCommit: 3)

        feed(&detector, ratio: 0.1, times: 1)
        #expect(!detector.isPinching)

        feed(&detector, ratio: 0.1, times: 2)
        #expect(detector.isPinching, "three agreeing frames commit it")
    }

    /// The bug this whole thing exists for: a hand mid-grab that throws one
    /// spurious "apart" frame must keep holding on.
    @Test func oneStrayApartFrameDoesNotRelease() {
        var detector = PinchDetector(framesToCommit: 3)
        feed(&detector, ratio: 0.1, times: 3)
        #expect(detector.isPinching)

        feed(&detector, ratio: 0.9, times: 1)

        #expect(detector.isPinching, "one bad frame must not let go")
    }

    /// A sustained release still works — this is not a one-way latch.
    @Test func aSustainedApartRunReleases() {
        var detector = PinchDetector(framesToCommit: 3)
        feed(&detector, ratio: 0.1, times: 3)

        feed(&detector, ratio: 0.9, times: 3)

        #expect(!detector.isPinching)
    }

    /// Evidence has to be *consecutive*: alternating frames never commit,
    /// because each one resets the other side's counter.
    @Test func alternatingFramesNeverCommit() {
        var detector = PinchDetector(framesToCommit: 3)

        for _ in 0..<10 {
            detector.record(ratio: 0.1, closeRatio: close, openRatio: open)
            detector.record(ratio: 0.9, closeRatio: close, openRatio: open)
        }

        #expect(!detector.isPinching, "never three in a row either way")
    }

    /// An unmeasurable frame is not evidence of being apart. A thumb that
    /// blinks out of tracking used to read as letting go.
    @Test func aMissingReadingHoldsTheCurrentState() {
        var detector = PinchDetector(framesToCommit: 3)
        feed(&detector, ratio: 0.1, times: 3)
        #expect(detector.isPinching)

        feed(&detector, ratio: nil, times: 10)

        #expect(detector.isPinching, "no reading is not a release")
    }

    /// Readings between the thresholds are ambiguous and count for neither
    /// side, so a hand hovering at the boundary holds rather than chattering.
    @Test func readingsInsideTheHysteresisBandHoldTheState() {
        var detector = PinchDetector(framesToCommit: 3)
        feed(&detector, ratio: 0.1, times: 3)

        feed(&detector, ratio: 0.4, times: 10)

        #expect(detector.isPinching)
    }

    /// Clearing evidence keeps the committed state — a hand coasting through a
    /// dropped frame resumes as what it was, not as a half-built opposite.
    @Test func clearingEvidenceKeepsTheCommittedState() {
        var detector = PinchDetector(framesToCommit: 3)
        feed(&detector, ratio: 0.1, times: 3)

        // Two frames of contrary evidence, then a dropout wipes them.
        feed(&detector, ratio: 0.9, times: 2)
        detector.clearEvidence()
        feed(&detector, ratio: 0.9, times: 2)

        #expect(detector.isPinching, "the earlier partial run must not carry over")
    }
}
