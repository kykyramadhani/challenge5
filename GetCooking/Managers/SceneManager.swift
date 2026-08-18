//
//  SceneManager.swift
//  GetCooking
//
//  Owns which screen the app is showing. Gameplay state (score,
//  timer, recipes) stays in GameStateManager, and the seat check now
//  lives inside GameplayView — this only handles navigation between
//  the main menu and the game.
//

import Foundation
import SwiftUI

@Observable
final class SceneManager {
    var path = NavigationPath()
    var selectedGame: GameOption?

    /// True from the moment the player taps Play until they leave the game.
    /// ContentView uses it to keep the shared camera mounted across the
    /// calibration → gameplay handover.
    var isInGameplayFlow = false

    func startGame(game: GameOption) {
        guard game.isAvailable else { return }
        selectedGame = game
        isInGameplayFlow = false
        path.append(game)
    }

    /// Push the game screen. Calibration (if the game needs it) runs *inside*
    /// GameplayView now, so there is a single navigation destination and no
    /// mid-flow view swapping.
    func goToGameplay() {
        isInGameplayFlow = true
        path.append("gameplay")
    }

    func goToMainMenu() {
        path = NavigationPath()
        selectedGame = nil
        isInGameplayFlow = false
    }
}
