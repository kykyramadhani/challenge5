//
//  ResetButtonExclusionTests.swift
//  PlayFeatTests
//
//  Split out of GetCookingTests.swift (created by Kyky on 11/08/26).
//

import Testing
import Foundation
import CoreGraphics
import SpriteKit
@testable import PlayFeat

/// Keeping a carried ingredient out of the reset button.
struct ResetButtonExclusionTests {

    private let button = CGPoint(x: 900, y: 700)
    private let keepOut: CGFloat = 150

    @Test func aPointOutsideTheZoneIsLeftAlone() {
        let clear = CGPoint(x: 400, y: 300)

        #expect(GameScene.pushedOut(clear, awayFrom: button, keepOut: keepOut) == clear)
    }

    /// Pushed straight out along the line it came in on, to the edge exactly.
    @Test func aPointInsideIsPushedToTheEdge() {
        let inside = CGPoint(x: 950, y: 700) // 50pt to the right of centre

        let pushed = GameScene.pushedOut(inside, awayFrom: button, keepOut: keepOut)

        #expect(abs(pushed.x - (button.x + keepOut)) < 0.001)
        #expect(abs(pushed.y - button.y) < 0.001)
    }

    /// Whatever comes out must be clear of the button, from any direction.
    @Test func nothingSurvivesInsideTheZone() {
        for angle in stride(from: 0.0, to: 2 * .pi, by: .pi / 6) {
            let inside = CGPoint(
                x: button.x + cos(angle) * 40,
                y: button.y + sin(angle) * 40
            )

            let pushed = GameScene.pushedOut(inside, awayFrom: button, keepOut: keepOut)

            #expect(pushed.vc_distance(to: button) >= keepOut - 0.001)
        }
    }

    /// Dead centre has no direction to push along — it must still come out,
    /// not divide by zero.
    @Test func deadCentreStillEscapes() {
        let pushed = GameScene.pushedOut(button, awayFrom: button, keepOut: keepOut)

        #expect(abs(pushed.vc_distance(to: button) - keepOut) < 0.001)
    }

    @Test func aZeroZoneExcludesNothing() {
        #expect(GameScene.pushedOut(button, awayFrom: button, keepOut: 0) == button)
    }
}
