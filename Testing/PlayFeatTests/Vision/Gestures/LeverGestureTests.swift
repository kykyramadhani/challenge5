//
//  LeverGestureTests.swift
//  PlayFeatTests
//
//  The dispenser handle: pinch, pull left to open, push right to close —
//  measured from where the pinch took hold, and never moved by a hand that
//  isn't pinching or is only predicted.
//

import CoreGraphics
import Testing
@testable import PlayFeat

struct LeverGestureTests {
    private func pinched(_ lever: inout LeverGesture, at x: CGFloat) -> LeverGesture.Event? {
        lever.observe(x: x, isPinching: true, isReliable: true)
    }

    @Test func pullLeftOpensThenPushRightCloses() {
        var lever = LeverGesture(travel: 100)
        #expect(pinched(&lever, at: 500) == nil)
        #expect(pinched(&lever, at: 450) == nil)
        #expect(pinched(&lever, at: 400) == .opened)
        #expect(lever.isOpen)

        #expect(pinched(&lever, at: 480) == nil)
        #expect(pinched(&lever, at: 500) == .closed)
        #expect(!lever.isOpen)
    }

    @Test func movingRightFirstDoesNothing() {
        var lever = LeverGesture(travel: 100)
        _ = pinched(&lever, at: 300)
        #expect(pinched(&lever, at: 500) == nil)
        #expect(!lever.isOpen)
    }

    /// An open hand drags nothing, and re-pinching starts a new measurement.
    @Test func onlyAPinchMovesTheHandle() {
        var lever = LeverGesture(travel: 100)
        _ = pinched(&lever, at: 500)
        #expect(lever.observe(x: 300, isPinching: false, isReliable: true) == nil)
        #expect(pinched(&lever, at: 300) == nil)
        #expect(!lever.isOpen)
    }

    /// A hand coasting through a tracking gap neither moves the handle nor
    /// lets go of it.
    @Test func aPredictedHandHoldsTheHandle() {
        var lever = LeverGesture(travel: 100)
        _ = pinched(&lever, at: 500)
        #expect(lever.observe(x: 350, isPinching: true, isReliable: false) == nil)
        #expect(lever.observe(x: nil, isPinching: false, isReliable: false) == nil)
        #expect(pinched(&lever, at: 400) == .opened)
    }
}
