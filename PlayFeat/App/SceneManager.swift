//
//  SceneManager.swift
//  PlayFeat
//
//  Owns which screen the app is showing. Gameplay state (score, timer,
//  recipes) stays in GameStateManager, and the tutorial and seat check live
//  inside GameplayView — this only decides between the full-screen
//  destinations in AppScreen.
//

import Foundation

@Observable
final class SceneManager {
    private(set) var screen: AppScreen = .mainMenu

    /// True until the walkthrough has been read or skipped this launch.
    private(set) var isInTutorial = true

    /// Walkthrough read, or skipped.
    func finishTutorial() {
        isInTutorial = false
    }

    func play() {
        screen = .gameplay
    }

    /// Leaving `.gameplay` removes GameplayView, which tears down its camera
    /// and scene before the results show.
    func goToPostGame(_ result: GameResult) {
        screen = .postGame(result)
    }

    /// Play Again from the results screen. Coming from `.postGame`, this
    /// builds a brand-new GameplayView — and with it a fresh GameStateManager —
    /// so the seat check and countdown run again just like the first time.
    func replayGame() {
        screen = .gameplay
    }

    func goToMainMenu() {
        screen = .mainMenu
    }

    func goToShop() {
        screen = .shop
    }
}
