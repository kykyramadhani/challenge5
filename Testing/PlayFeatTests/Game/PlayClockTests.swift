//
//  PlayClockTests.swift
//  PlayFeatTests
//
//  The play clock every deadline is measured on, and the countdowns set on it.
//

import Testing
import Foundation
@testable import PlayFeat

struct PlayClockTests {

    @Test func advancingCreditsTheTimeBetweenTicks() {
        var clock = PlayClock(wallTime: 100)

        clock.advance(to: 100.1)
        clock.advance(to: 100.3)

        #expect(abs(clock.elapsed - 0.3) < 0.0001)
    }

    /// A stall must not hand the player a dish failure they never saw coming.
    @Test func aLongGapIsCappedToOneTick() {
        var clock = PlayClock(wallTime: 100)

        clock.advance(to: 105)

        #expect(clock.elapsed == PlayClock.maxTickDelta)
    }

    /// Paused time is skipped, not credited in one lump on resume.
    @Test func holdingSkipsThePausedTime() {
        var clock = PlayClock(wallTime: 100)
        clock.hold(at: 100.2)   // paused...
        clock.hold(at: 160)     // ...for a minute

        clock.advance(to: 160.1)

        #expect(abs(clock.elapsed - 0.1) < 0.0001)
    }

    @Test func aCountdownDrainsFromFullToEmpty() {
        let countdown = Countdown(duration: 10, startingAt: 5)

        #expect(countdown.fractionLeft(at: 5) == 1)
        #expect(abs(countdown.fractionLeft(at: 10) - 0.5) < 0.0001)
        #expect(countdown.fractionLeft(at: 20) == 0, "clamped, never negative")
        #expect(!countdown.hasRunOut(at: 14.9))
        #expect(countdown.hasRunOut(at: 15))
    }

    /// The speed bonus banks whole seconds only.
    @Test func wholeSecondsLeftAreFloored() {
        let countdown = Countdown(duration: 10, startingAt: 0)

        #expect(countdown.wholeSecondsLeft(at: 6.3) == 3)
        #expect(countdown.wholeSecondsLeft(at: 12) == 0)
    }

    @Test func noCountdownReadsAsEmpty() {
        #expect(Countdown.none.fractionLeft(at: 3) == 0)
    }
}
