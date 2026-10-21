//
//  ShiftCountdownTests.swift
//  PlayFeatTests
//
//  The 3-2-1 ticks on time, and play never begins before the camera is ready.
//

import Testing
@testable import PlayFeat

struct ShiftCountdownTests {
    @Test func countsThreeTwoOneOneSecondApart() {
        #expect(ShiftCountdown.number(after: 0, isCameraReady: false) == 3)
        #expect(ShiftCountdown.number(after: 0.99, isCameraReady: true) == 3)
        #expect(ShiftCountdown.number(after: 1, isCameraReady: true) == 2)
        #expect(ShiftCountdown.number(after: 2.5, isCameraReady: true) == 1)
    }

    /// A ready camera doesn't cut the count short.
    @Test func aReadyCameraStillWaitsForTheWholeCount() {
        #expect(ShiftCountdown.number(after: 2.99, isCameraReady: true) == 1)
        #expect(ShiftCountdown.number(after: ShiftCountdown.duration, isCameraReady: true) == nil)
    }

    /// A slow camera holds the count on 1, however long it takes.
    @Test func holdsOnOneUntilTheCameraIsReady() {
        #expect(ShiftCountdown.number(after: ShiftCountdown.duration, isCameraReady: false) == 1)
        #expect(ShiftCountdown.number(after: 30, isCameraReady: false) == 1)
        #expect(ShiftCountdown.number(after: 30, isCameraReady: true) == nil)
    }
}
