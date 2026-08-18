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
    var selectedGame: GameOption?
    var hasCompletedCalibration = false
    var isInGameplayFlow = false

    func startGame(game: GameOption) {
        guard game.isAvailable else { return }
        selectedGame = game
        hasCompletedCalibration = false
        isInGameplayFlow = false
        path.append(game)
    }

    func goToGameplay() {
        hasCompletedCalibration = false
        isInGameplayFlow = true
        path.append("gameplay")
    }

    /// Seat check passed.
    func beginPlaying() {
        hasCompletedCalibration = true
    }

    func goToMainMenu() {
        path = NavigationPath()
        selectedGame = nil
        hasCompletedCalibration = false
        isInGameplayFlow = false
    }
}
