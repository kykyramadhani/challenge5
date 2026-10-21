//
//  PauseTests.swift
//  PlayFeatTests
//
//  Pausing a run: what the app does when it leaves the foreground, so the
//  clock can't cost a life while hand tracking is off.
//

import Testing
@testable import PlayFeat

@MainActor
struct PauseTests {

    @Test func pausingStopsTheRunAndResumingStartsItAgain() {
        let game = makeGame()
        game.start()

        game.pause()
        #expect(game.isPaused)

        game.resume()
        #expect(!game.isPaused)
    }

    /// Leaving the app goes through `.inactive` and then `.background`, so
    /// pause arrives twice; the second must not undo the first.
    @Test func pausingTwiceKeepsTheRunPaused() {
        let game = makeGame()
        game.start()

        game.pause()
        game.pause()

        #expect(game.isPaused)
    }

    /// Before the 3-2-1 finishes there is no clock to freeze; pausing then
    /// would leave the run frozen the moment it started.
    @Test func pausingBeforeTheRunStartsDoesNothing() {
        let game = makeGame()

        game.pause()

        #expect(!game.isPaused)
    }

    @Test func pausingAfterTheRunEndsDoesNothing() {
        let game = makeGame(startingLives: 1)
        game.start()
        game.failDish()

        game.pause()

        #expect(!game.isPaused)
    }

    @Test func thePausedDishClockDoesNotRunDown() async throws {
        let game = makeGame()
        game.start()
        try await Task.sleep(for: .milliseconds(200))

        game.pause()
        let frozen = game.dishTimeFraction
        try await Task.sleep(for: .milliseconds(400))

        #expect(game.dishTimeFraction == frozen)
    }

    @Test func theDishClockRunsDownAgainAfterResuming() async throws {
        let game = makeGame()
        game.start()
        game.pause()
        try await Task.sleep(for: .milliseconds(200))
        let frozen = game.dishTimeFraction

        game.resume()
        try await Task.sleep(for: .milliseconds(400))

        #expect(game.dishTimeFraction < frozen)
    }
}
