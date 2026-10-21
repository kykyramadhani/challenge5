//
//  ShiftPhaseTests.swift
//  PlayFeatTests
//  Created by Owen Limantoro on 21/10/26.
//
//  The order a kitchen shift opens in: seat check, 3-2-1, play.
//

import Testing
@testable import PlayFeat

struct ShiftPhaseTests {

    @Test func aShiftWithACameraOpensOnTheSeatCheck() {
        #expect(ShiftPhase.opening(withSeatCheck: true) == .seatCheck)
    }

    /// The simulator has no camera to check against, so it counts straight in.
    @Test func aShiftWithoutASeatCheckOpensOnTheCountdown() {
        #expect(ShiftPhase.opening(withSeatCheck: false) == .countdown)
    }

    /// The clocks only start after the 3-2-1, never straight off the check.
    @Test func theSeatCheckLeadsToTheCountdownAndThenPlay() {
        let afterCheck = ShiftPhase.seatCheck.next

        #expect(afterCheck == .countdown)
        #expect(afterCheck.next == .playing)
    }

    @Test func playingIsTheLastPhase() {
        #expect(ShiftPhase.playing.next == .playing)
    }
}
