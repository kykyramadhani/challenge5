//
//  GameEventTests.swift
//  PlayFeatTests
//
//  Which events make the scene clear the table and lay the round out again.
//

import Testing
@testable import PlayFeat

struct GameEventTests {

    @Test func aNewRunWipesTheBoard() {
        #expect(GameEvent.runRestarted.wipesBoard)
    }

    /// The run carries on with a fresh recipe, so the old table has to go.
    @Test func aLostLifeWithLivesLeftWipesTheBoard() {
        #expect(GameEvent.lifeLost(livesLeft: 1).wipesBoard)
    }

    /// The run is over: the board stays as it was under the game-over cover.
    @Test func theLastLifeLeavesTheBoard() {
        #expect(!GameEvent.lifeLost(livesLeft: 0).wipesBoard)
    }

    /// Only the plate's contents move; the rest of the table stays put.
    @Test func discardingThePlateLeavesTheBoard() {
        #expect(!GameEvent.plateDiscarded.wipesBoard)
    }
}
