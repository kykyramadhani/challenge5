//
//  ContentView.swift
//  VisionChef
//
//  Root view that switches between the main menu and gameplay.
//  SceneManager owns which screen is showing; GameStateManager and
//  HandPoseManager live inside GameplayView and are created fresh
//  each time the player starts a game.
//

import SwiftUI

struct ContentView: View {
    @State private var sceneManager = SceneManager()

    var body: some View {
        switch sceneManager.currentScreen {
        case .mainMenu:
            MainMenuView { sceneManager.startGame() }
        case .game:
            GameplayView(sceneManager: sceneManager)
        }
    }
}

#Preview {
    ContentView()
}
