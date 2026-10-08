//
//  PinchClassifierTests.swift
//  PlayFeatTests
//
//  Split out of GetCookingTests.swift (created by Kyky on 11/08/26).
//

import Testing
import Foundation
import CoreGraphics
@testable import PlayFeat

/// Grabbing is a thumb-to-index-finger pinch. The shipped thresholds are
/// 0.3 (grab) and 0.5 (open), with hysteresis in between.
struct PinchClassifierTests {

    private let palmLength: CGFloat = 1.0

    /// The shipped values, so these tests fail if the thresholds drift apart
    /// from the fixtures below rather than silently going vacuous.
    private let closeRatio: CGFloat = 0.3
    private let openRatio: CGFloat = 0.5

    /// Tips touching. They never reach 0 — the joints sit inside the fingers —
    /// so this has to clear the grab threshold with room, not just beat zero.
    @Test func tipsTogetherReadAsAPinch() {
        let ratio = HandClassifier.pinchRatio(
            thumbTip: CGPoint(x: 0, y: 0),
            indexTip: CGPoint(x: 0.15, y: 0),
            palmLength: palmLength
        )

        #expect(ratio == 0.15)
        #expect(ratio! <= closeRatio, "clears the shipped grab threshold")
    }

    /// A spread open hand puts the two tips a full palm-width apart or more —
    /// comfortably past the open threshold, never mistakeable for a grab.
    @Test func aSpreadHandIsWellClearOfTheGrabThreshold() {
        let ratio = HandClassifier.pinchRatio(
            thumbTip: CGPoint(x: 0, y: 0),
            indexTip: CGPoint(x: 1.1, y: 0),
            palmLength: palmLength
        )

        #expect(ratio! >= openRatio, "reads as open, not held by hysteresis")
    }

    /// The whole point of the change: a clenched fist is no longer a grab.
    ///
    /// This is the close call for a thumb-to-*index* pinch specifically — a
    /// fist folds the thumb across the curled index, so these two tips end up
    /// nearer each other than any other pair on the hand. ~0.6 palm lengths
    /// still has to land on the open side of the threshold.
    @Test func aClenchedFistIsNotAGrab() {
        let ratio = HandClassifier.pinchRatio(
            thumbTip: CGPoint(x: 0, y: 0),
            indexTip: CGPoint(x: 0.6, y: 0),
            palmLength: palmLength
        )

        #expect(ratio! >= openRatio, "a fist must read as open")
    }

    /// Scale-free: the same pinch twice as far from the camera must classify
    /// identically, since the gap is divided by palm length.
    @Test func pinchIsIndependentOfDistanceFromCamera() {
        let near = HandClassifier.pinchRatio(
            thumbTip: CGPoint(x: 0, y: 0),
            indexTip: CGPoint(x: 0.3, y: 0),
            palmLength: palmLength
        )
        let far = HandClassifier.pinchRatio(
            thumbTip: CGPoint(x: 0, y: 0),
            indexTip: CGPoint(x: 0.15, y: 0),
            palmLength: palmLength / 2
        )

        #expect(near == far)
    }

    /// A tip that dropped out of tracking is not a grab — the caller opens the
    /// hand rather than clamping shut on whatever is nearby.
    @Test func aMissingTipHasNoPinchMeasurement() {
        #expect(HandClassifier.pinchRatio(
            thumbTip: nil, indexTip: CGPoint(x: 0.2, y: 0), palmLength: palmLength
        ) == nil)

        #expect(HandClassifier.pinchRatio(
            thumbTip: CGPoint(x: 0, y: 0), indexTip: nil, palmLength: palmLength
        ) == nil)
    }

    @Test func anUnmeasurablePalmHasNoPinchMeasurement() {
        #expect(HandClassifier.pinchRatio(
            thumbTip: CGPoint(x: 0, y: 0),
            indexTip: CGPoint(x: 0.2, y: 0),
            palmLength: 0
        ) == nil)
    }
}
