//
//  PlayAreaClampTests.swift
//  PlayFeatTests
//
//  Split out of GetCookingTests.swift (created by Kyky on 11/08/26).
//

import Testing
import Foundation
import CoreGraphics
import SpriteKit
@testable import PlayFeat

struct PlayAreaClampTests {

    private let screen = CGSize(width: 834, height: 1194)
    private let radius: CGFloat = 85

    /// A hand reaching past the edge of the camera's view maps outside the
    /// scene. The bubble must stop at the frame — once it leaves there is no
    /// way to reach it again.
    @Test func aBubbleDraggedPastTheEdgeStopsAtTheFrame() {
        let offLeft = GameScene.clamped(CGPoint(x: -300, y: 600), radius: radius, in: screen)
        let offRight = GameScene.clamped(CGPoint(x: 1200, y: 600), radius: radius, in: screen)
        let offBottom = GameScene.clamped(CGPoint(x: 400, y: -80), radius: radius, in: screen)
        let offTop = GameScene.clamped(CGPoint(x: 400, y: 2000), radius: radius, in: screen)

        #expect(offLeft.x == radius)
        #expect(offRight.x == screen.width - radius)
        #expect(offBottom.y == radius)
        #expect(offTop.y == screen.height - radius)
    }

    /// Clamping must not nudge a bubble that is already comfortably inside,
    /// or dragging would feel like it was fighting the hand.
    @Test func interiorPointsAreUntouched() {
        let inside = CGPoint(x: 400, y: 600)

        #expect(GameScene.clamped(inside, radius: radius, in: screen) == inside)
    }

    /// A scene narrower than two radii would build a reversed range, which
    /// traps at runtime rather than returning anything.
    @Test func aSceneSmallerThanTheBubbleDoesNotTrap() {
        let tiny = CGSize(width: 40, height: 40)

        let clamped = GameScene.clamped(CGPoint(x: 500, y: 500), radius: radius, in: tiny)

        #expect(clamped == CGPoint(x: radius, y: radius))
    }
}
