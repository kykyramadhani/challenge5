//
//  SceneManager.swift
//  GetCooking
//
//  Owns which screen the app is showing. Gameplay state (score,
//  timer, recipes) stays in GameStateManager — this only handles
//  navigation between the main menu and the game.
//

import Foundation
import Combine

enum AppScreen {
    case mainMenu
    case game
}

final class SceneManager: ObservableObject {
    @Published var currentScreen: AppScreen = .mainMenu

    func startGame() {
        currentScreen = .game
    }

    func goToMainMenu() {
        currentScreen = .mainMenu
    }
}
