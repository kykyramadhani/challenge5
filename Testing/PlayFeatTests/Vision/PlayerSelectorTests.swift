//
//  PlayerSelectorTests.swift
//  PlayFeatTests
//
//  Who counts as the player: whoever sits in the calibration frame until the
//  seat check passes, then only the person who calibrated.
//

import AVFoundation
import CoreGraphics
import Testing
@testable import PlayFeat

struct PlayerSelectorTests {
    typealias Body = HumanBodyPoseManager.BodyCandidate

    /// Square view and buffer, so a normalized point maps straight across:
    /// shoulders at y 0.70 land at y 300 on screen.
    private static let bufferSize = CGSize(width: 1000, height: 1000)

    /// Shoulders `span` wide, centred on (`x`, `y`) in normalized Vision space.
    private func body(at x: CGFloat, _ y: CGFloat = 0.70, span: CGFloat = 0.20) -> Body {
        Body(
            head: nil,
            leftShoulder: CGPoint(x: x - span / 2, y: y),
            rightShoulder: CGPoint(x: x + span / 2, y: y),
            leftHip: nil,
            rightHip: nil,
            leftWrist: nil,
            rightWrist: nil
        )
    }

    /// A calibration frame 200pt wide, centred on normalized `x`, at shoulder height.
    private func zone(aroundX x: CGFloat) -> PlayerSelector.Zone {
        PlayerSelector.Zone(
            frame: CGRect(x: x * 1000 - 100, y: 200, width: 200, height: 200),
            viewSize: Self.bufferSize,
            gravity: .resizeAspectFill
        )
    }

    private func selector(zoneAroundX x: CGFloat) -> PlayerSelector {
        var selector = PlayerSelector()
        selector.zone = zone(aroundX: x)
        return selector
    }

    // MARK: - Before calibration: the frame decides

    @Test func beforeTheLockTheBodyInTheFrameIsThePlayer() {
        let bodies = [body(at: 0.2), body(at: 0.5), body(at: 0.8)]
        let selector = selector(zoneAroundX: 0.5)

        #expect(selector.playerIndex(in: bodies, bufferSize: Self.bufferSize) == 1)
    }

    @Test func beforeTheLockAWiderBodyOutsideTheFrameIsIgnored() {
        let bodies = [body(at: 0.85, span: 0.40), body(at: 0.5)]
        let selector = selector(zoneAroundX: 0.5)

        #expect(selector.playerIndex(in: bodies, bufferSize: Self.bufferSize) == 1)
    }

    @Test func beforeTheLockNobodyInTheFrameMeansNoPlayer() {
        let selector = selector(zoneAroundX: 0.8)

        #expect(selector.playerIndex(in: [body(at: 0.2)], bufferSize: Self.bufferSize) == nil)
    }

    // MARK: - After calibration: only the calibrated person

    @Test func afterTheLockOnlyTheCalibratedPersonIsThePlayer() {
        var selector = selector(zoneAroundX: 0.5)
        selector.lock(onto: body(at: 0.5))

        // A bystander now stands in the frame too, listed first and looking
        // wider; the player has leaned a little to the side.
        let bodies = [body(at: 0.42, span: 0.35), body(at: 0.53)]

        #expect(selector.playerIndex(in: bodies, bufferSize: Self.bufferSize) == 1)
    }

    @Test func afterTheLockNobodyNearTheAnchorMeansNoPlayer() {
        var selector = PlayerSelector()
        selector.lock(onto: body(at: 0.5))

        #expect(selector.playerIndex(in: [body(at: 0.85)], bufferSize: Self.bufferSize) == nil)
        #expect(selector.playerIndex(in: [], bufferSize: Self.bufferSize) == nil)
    }

    /// Small shifts each detection add up: the anchor follows the player
    /// across the screen, where comparing to the calibration spot would lose them.
    @Test func theLockFollowsThePlayerAsTheyMove() {
        var selector = PlayerSelector()
        selector.lock(onto: body(at: 0.50))

        for step in 1...5 {
            let x = 0.50 + CGFloat(step) * 0.05
            let bodies = [body(at: 0.30), body(at: x)]
            let player = selector.playerIndex(in: bodies, bufferSize: Self.bufferSize)
            #expect(player == 1, "player at x \(x)")
            if let player { selector.follow(bodies[player]) }
        }

        #expect((selector.anchor?.chest.x ?? 0) > 0.74)
    }

    /// A jump bigger than a lean is someone else, not the player moving.
    @Test func aBodyBeyondTheToleranceIsNotThePlayer() {
        var selector = PlayerSelector()
        selector.lock(onto: body(at: 0.50, span: 0.20))  // reach: 0.20 × 0.5 = 0.10

        #expect(selector.playerIndex(in: [body(at: 0.59)], bufferSize: Self.bufferSize) == 0)
        #expect(selector.playerIndex(in: [body(at: 0.62)], bufferSize: Self.bufferSize) == nil)
    }

    @Test func followIsIgnoredBeforeTheLock() {
        var selector = PlayerSelector()
        selector.follow(body(at: 0.5))

        #expect(!selector.isLocked)
    }

    @Test func resetForgetsTheLockAndTheFrame() {
        var selector = selector(zoneAroundX: 0.8)
        selector.lock(onto: body(at: 0.8))
        selector.reset()

        #expect(!selector.isLocked)
        #expect(selector.zone == nil)
        #expect(selector.playerIndex(in: [body(at: 0.2)], bufferSize: Self.bufferSize) == 0)
    }
}
