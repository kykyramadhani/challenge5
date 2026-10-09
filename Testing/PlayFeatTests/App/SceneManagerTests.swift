//
//  SceneManagerTests.swift
//  PlayFeatTests
//
//  Which screen the app lands on after each navigation call.
//

import Testing
@testable import PlayFeat

@MainActor
struct SceneManagerTests {

    private let result = GameResult(dishesByType: ["salad": 2], speedBonus: 5)

    @Test func theAppOpensOnTheMainMenuWithTheTutorialStillToRead() {
        let manager = SceneManager()

        #expect(manager.screen == .mainMenu)
        #expect(manager.isInTutorial)
    }

    @Test func playingOpensTheGameplayScreen() {
        let manager = SceneManager()

        manager.play()

        #expect(manager.screen == .gameplay)
    }

    /// The results screen carries the finished run's outcome with it.
    @Test func endingARunShowsItsResults() {
        let manager = SceneManager()
        manager.play()

        manager.goToPostGame(result)

        #expect(manager.screen == .postGame(result))
    }

    @Test func playAgainGoesFromTheResultsBackIntoGameplay() {
        let manager = SceneManager()
        manager.goToPostGame(result)

        manager.replayGame()

        #expect(manager.screen == .gameplay)
    }

    @Test func theShopIsReachableAndItsBackButtonReturnsToTheMenu() {
        let manager = SceneManager()

        manager.goToShop()
        #expect(manager.screen == .shop)

        manager.goToMainMenu()
        #expect(manager.screen == .mainMenu)
    }

    /// Read once per launch: a second run goes straight to the seat check.
    @Test func finishingTheTutorialSkipsItForLaterRuns() {
        let manager = SceneManager()

        manager.finishTutorial()
        manager.replayGame()

        #expect(!manager.isInTutorial)
    }
}
