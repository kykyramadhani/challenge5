//
//  HoverDetectorTests.swift
//  PlayFeatTests
//
//  Split out of GetCookingTests.swift (created by Kyky on 11/08/26).
//

import Testing
import Foundation
import CoreGraphics
@testable import PlayFeat

struct HoverDetectorTests {

    /// The shipped `maxFrameGap` deliberately caps how much a single frame can
    /// contribute; these tests jump the clock in one step, so they lift it.
    private func detector(dwell: TimeInterval = 1.0) -> HoverDetector {
        var detector = HoverDetector()
        detector.dwellDuration = dwell
        detector.maxFrameGap = .infinity
        return detector
    }

    // `update` is mutating and `#expect` expands its argument into a closure
    // that captures immutably, so every call is hoisted into a `let` first.

    /// The whole gesture: hold still over the bin and it fires once the full
    /// dwell has elapsed, and not a frame before.
    @Test func holdingTheDwellFires() {
        var detector = detector()

        let atStart = detector.update(isHovering: true, now: 0)
        let midway = detector.update(isHovering: true, now: 1.0)
        let atDwell = detector.update(isHovering: true, now: 2.0)

        #expect(!atStart)
        #expect(midway)
        #expect(!atDwell)
    }

    /// Moving off the bin part-way through starts the next attempt from zero,
    /// so a hand brushing past twice can never add up to a discard.
    @Test func movingAwayResetsTheDwell() {
        var detector = detector()

        _ = detector.update(isHovering: true, now: 0)
        _ = detector.update(isHovering: true, now: 0.9)

        _ = detector.update(isHovering: false, now: 1.0) // hand leaves

        let restarted = detector.update(isHovering: true, now: 2.0)
        let partway = detector.update(isHovering: true, now: 2.5)
        let completed = detector.update(isHovering: true, now: 3.0)

        #expect(!restarted)
        #expect(!partway, "only 0.5s into the fresh dwell")
        #expect(completed)
    }

    /// A hand left resting on the bin discards once, not on every frame for as
    /// long as it sits there.
    @Test func firesOnceWhileTheHandStaysPut() {
        var detector = detector()
        _ = detector.update(isHovering: true, now: 0)

        let first = detector.update(isHovering: true, now: 2.0)
        let second = detector.update(isHovering: true, now: 4.0)
        let third = detector.update(isHovering: true, now: 10.0)

        #expect(first)
        #expect(!second, "a parked hand must not discard over and over")
        #expect(!third)
    }

    /// Leaving and coming back is a deliberate second discard.
    @Test func leavingRearmsForASecondDiscard() {
        var detector = detector()
        _ = detector.update(isHovering: true, now: 0)
        let first = detector.update(isHovering: true, now: 2.0)

        _ = detector.update(isHovering: false, now: 2.5)    // hand leaves
        _ = detector.update(isHovering: true, now: 3.0)
        let second = detector.update(isHovering: true, now: 5.0)

        #expect(first)
        #expect(second)
    }

    /// Pausing stops SpriteKit calling `update(_:)` at all, so `now` jumps
    /// seconds ahead on resume. A hand resting over the bin across a pause must
    /// not have its dwell completed for it. Uses the shipped cap, not the test one.
    @Test func aPausedSceneDoesNotCompleteTheDwell() {
        var detector = HoverDetector()
        _ = detector.update(isHovering: true, now: 0)

        let afterPause = detector.update(isHovering: true, now: 30)

        #expect(!afterPause)
    }

    /// `progress` drives the ring around the bin, so it has to track the dwell
    /// and clear the moment the hand leaves.
    @Test func progressTracksTheDwellAndClearsOnLeaving() {
        var detector = detector()

        _ = detector.update(isHovering: true, now: 0)
        _ = detector.update(isHovering: true, now: 0.5)

        #expect(abs(detector.progress - 0.5) < 0.001)

        _ = detector.update(isHovering: false, now: 0.6)

        #expect(detector.progress == 0)
    }
}
