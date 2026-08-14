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

    func startGame() {
        currentScreen = .game
    }

    func goToMainMenu() {
        currentScreen = .mainMenu
    }
}
