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

    /// Play pressed. The player sits themselves in frame before the game
    /// itself starts, so this opens the seat check rather than gameplay.
    func startGame() {
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
