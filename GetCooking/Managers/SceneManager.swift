//
//  SceneManager.swift
//  GetCooking
//
//  Owns which screen the app is showing. Gameplay state (score,
//  timer, recipes) stays in GameStateManager — this only handles
//  navigation between the main menu and the game.
//

import Foundation

@Observable
final class SceneManager {
    var currentScreen: AppScreen = .mainMenu

    /// Play pressed. The walkthrough and the seat check both come before
    /// gameplay, so this opens the first of them rather than the game.
    func startGame() {
        currentScreen = .tutorial
    }

    /// Walkthrough read, or skipped.
    func finishTutorial() {
        currentScreen = .calibration
    }

    /// Seat check passed.
    func beginPlaying() {
        currentScreen = .game
    }

    func goToMainMenu() {
        currentScreen = .mainMenu
    }
}
