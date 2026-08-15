//
//  SceneManager.swift
//  GetCooking
//
//  Owns which screen the app is showing. Gameplay state (score,
//  timer, recipes) stays in GameStateManager — this only handles
//  navigation between the main menu and the game.
//

import Foundation
import SwiftUI

@Observable
final class SceneManager {
    var path = NavigationPath()
    var selectedGame : GameOption?

    func startGame(game: GameOption) {
        guard game.isAvailable else { return }
        selectedGame = game
        path.append(game)
    }

    func goToGameplay() {
        path.append("gameplay")
    }

    func goToMainMenu() {
        path = NavigationPath()
    }
}
