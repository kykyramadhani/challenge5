//
//  DragEasingTests.swift
//  PlayFeatTests
//
//  Split out of GetCookingTests.swift (created by Kyky on 11/08/26).
//

import Testing
import Foundation
import CoreGraphics
import SpriteKit
@testable import PlayFeat

/// Easing a carried ingredient toward the hand.
struct DragEasingTests {

    private let sixtyHz: TimeInterval = 1.0 / 60
    private let oneTwentyHz: TimeInterval = 1.0 / 120

    /// The base is defined as "one 60Hz frame", so at 60Hz it passes straight
    /// through — otherwise the number in `dragSmoothing` would mean nothing.
    @Test func aSixtyHertzFrameUsesTheBaseUnchanged() {
        let eased = GameScene.easing(base: 0.5, delta: sixtyHz)

        #expect(abs(eased - 0.5) < 0.0001)
    }

    /// The whole point: a ProMotion iPad draws twice as often, so each frame
    /// must move the bubble less or the drag ends up twice as twitchy on the
    /// device this is tuned on.
    @Test func aShorterFrameEasesLess() {
        let eased = GameScene.easing(base: 0.5, delta: oneTwentyHz)

        #expect(eased < 0.5)
        // Two 120Hz frames have to land where one 60Hz frame does.
        let afterTwo = 1 - (1 - eased) * (1 - eased)
        #expect(abs(afterTwo - 0.5) < 0.0001)
    }

    @Test func aLongerFrameEasesMore() {
        #expect(GameScene.easing(base: 0.5, delta: 2 / 60.0) > 0.5)
    }

    /// After a stall, closing the whole gap at once would snap a carried
    /// bubble across the screen.
    @Test func aStalledFrameIsCapped() {
        let stalled = GameScene.easing(base: 0.5, delta: 5)
        let capped = GameScene.easing(base: 0.5, delta: GameScene.maxEasingDelta)

        #expect(stalled == capped)
        #expect(stalled < 1)
    }

    /// The first frame has no previous timestamp to measure against.
    @Test func noPreviousFrameFallsBackToTheBase() {
        #expect(GameScene.easing(base: 0.5, delta: 0) == 0.5)
    }

    @Test func degenerateBasesAreHandled() {
        #expect(GameScene.easing(base: 0, delta: sixtyHz) == 0, "frozen")
        #expect(GameScene.easing(base: 1, delta: sixtyHz) == 1, "snaps")
    }

    /// Easing must actually close the gap, and never overshoot it.
    @Test func easingMovesTowardTheTargetWithoutOvershooting() {
        let from = CGPoint(x: 0, y: 0)
        let to = CGPoint(x: 100, y: 50)

        let half = from.vc_eased(toward: to, by: 0.5)
        #expect(half == CGPoint(x: 50, y: 25))

        #expect(from.vc_eased(toward: to, by: 0) == from)
        #expect(from.vc_eased(toward: to, by: 1) == to)
    }
}
