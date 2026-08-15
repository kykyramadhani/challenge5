//
//  ContentView.swift
//  VisionChef
//
//  Root view that switches between the main menu and gameplay.
//  SceneManager owns which screen is showing; GameStateManager and
//  HandPoseManager live inside GameplayView and are created fresh
//  each time the player starts a game.
//

import Combine
import SwiftUI

struct ContentView: View {
    @State private var sceneManager = SceneManager()

    var body: some View {
        NavigationStack(path: $sceneManager.path) {
            MainMenuView(sceneManager: sceneManager)
                .navigationDestination(for: GameOption.self) { game in
                    GameOpening(game: game, sceneManager: sceneManager)
                }
                .navigationDestination(for: String.self) { destination in
                    if destination == "gameplay" {
                        GameplayView(sceneManager: sceneManager)
                            .navigationBarBackButtonHidden(true)
                    }
                }
        }
        .tint(.appSecondaryText)
    }
}

#Preview {
    ContentView()
}
