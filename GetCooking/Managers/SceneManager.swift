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
    var isInTutorial = true

    func startGame(game: GameOption) {
        guard game.isAvailable else { return }
        selectedGame = game
        isInGameplayFlow = false
        path.append(game)
    }

    /// Start straight from the opening screen. With a single game there is no
    /// carousel to pick from, so this both records the game — Play Again on the
    /// results screen restarts whatever is selected — and drops into the run.
    func play(_ game: GameOption) {
        guard game.isAvailable else { return }
        selectedGame = game
        goToGameplay()
    }

    /// Walkthrough read, or skipped.
    func finishTutorial() {
        isInTutorial = false
    }

    /// Push the game screen. Calibration (if the game needs it) runs *inside*
    /// GameplayView now, so there is a single navigation destination and no
    /// mid-flow view swapping.
    func goToGameplay() {
        isInGameplayFlow = true
        path.append("gameplay")
    }

    /// Show the end-of-run results as their own screen. Resetting the path
    /// first drops GameplayView from the stack — tearing down its camera and
    /// scene — and then pushes PostGame on top of the menu.
    func goToPostGame(_ result: GameResult) {
        isInGameplayFlow = false
        path = NavigationPath()
        path.append(result)
    }

    /// Play Again from the results screen: start a brand-new run of the same
    /// game. A fresh GameplayView means a fresh GameStateManager, so it runs
    /// the seat check and countdown again just like the first time.
    func replayGame() {
        guard selectedGame != nil else { goToMainMenu(); return }
        path = NavigationPath()
        goToGameplay()
    }

    func goToMainMenu() {
        path = NavigationPath()
        selectedGame = nil
        isInGameplayFlow = false
    }
}
