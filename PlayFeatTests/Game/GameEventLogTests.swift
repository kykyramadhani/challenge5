//
//  GameEventLogTests.swift
//  PlayFeatTests
//
//  How GameScene and the HUD pick up events without missing any.
//

import Testing
@testable import PlayFeat

struct GameEventLogTests {

    @Test func entriesAreNumberedInOrder() {
        var log = GameEventLog()
        log.record(.plateDiscarded)
        log.record(.lifeLost(livesLeft: 2))

        #expect(log.entries.map(\.number) == [1, 2])
        #expect(log.latest?.event == .lifeLost(livesLeft: 2))
    }

    /// Two events between frames: the scene, remembering only the last number
    /// it handled, still gets both — in order.
    @Test func aConsumerGetsEverythingNewerThanWhatItHandled() {
        var log = GameEventLog()
        log.record(.plateDiscarded)
        let handled = log.latest?.number ?? 0
        log.record(.plateDiscarded)
        log.record(.lifeLost(livesLeft: 1))

        #expect(log.entries(after: handled).map(\.event) == [.plateDiscarded, .lifeLost(livesLeft: 1)])
    }

    @Test func eventsAreCountedByKind() {
        var log = GameEventLog()
        log.record(.runRestarted)
        log.record(.plateDiscarded)
        log.record(.runRestarted)

        #expect(log.count(of: .runRestarted) == 2)
    }
}
