//
//  StirGestureTests.swift
//  PlayFeatTests
//
//  Stirring counts pinched hands only — the opposite of washing — and a hand
//  coasting through a tracking gap never counts.
//

import Testing
@testable import PlayFeat

struct StirGestureTests {
    @Test func aPinchedSeenHandStirs() {
        #expect(StirGesture.step(isPinching: true, isPredicted: false) == .stir)
    }

    /// Letting go of the ladle starts the circle over.
    @Test func anOpenHandRestartsItsCircle() {
        #expect(StirGesture.step(isPinching: false, isPredicted: false) == .restart)
    }

    @Test func aPredictedHandNeitherStirsNorRestarts() {
        #expect(StirGesture.step(isPinching: true, isPredicted: true) == .hold)
        #expect(StirGesture.step(isPinching: false, isPredicted: true) == .hold)
    }
}
