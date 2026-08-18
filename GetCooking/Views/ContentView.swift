//
//  ContentView.swift
//  VisionChef
//
//  Root view that switches between the main menu, the seat check and
//  gameplay. SceneManager owns which screen is showing.
//
//  Both HandPoseManager *and* the camera preview live here rather than
//  inside a screen. The seat check and the game each need the camera, and
//  building either one per screen means tearing the capture pipeline down
//  and standing it back up mid-flow — a stall right as the countdown is
//  meant to start.
//
//  GameStateManager stays inside GameplayView, so every run starts fresh.
//

import Combine
import SwiftUI

struct ContentView: View {
    @State private var sceneManager = SceneManager()
    @StateObject private var handPoseManager = HandPoseManager()

    /// GetCooking starts the camera at its opening screen so it remains mounted
    /// throughout the calibration → gameplay handover. Other games mount it
    /// only after their Play button is pressed.
    private var showsCamera: Bool {
        guard let game = sceneManager.selectedGame else { return false }
        return game.requiresCalibration || sceneManager.isInGameplayFlow
    }

    var body: some View {
        ZStack {
            if showsCamera {
                CameraPreviewView(handPoseManager: handPoseManager)
                    .ignoresSafeArea()
            }

            NavigationStack(path: $sceneManager.path) {
                MainMenuView(sceneManager: sceneManager)
                    .navigationDestination(for: GameOption.self) { game in
                        GameOpening(game: game, sceneManager: sceneManager)
                    }
                    .navigationDestination(for: String.self) { destination in
                        if destination == "gameplay" {
                            if sceneManager.selectedGame?.requiresCalibration == true,
                               !sceneManager.hasCompletedCalibration {
                                SeatCalibrationView(handPoseManager: handPoseManager) {
                                    sceneManager.beginPlaying()
                                }
                            } else {
                                GameplayView(
                                    sceneManager: sceneManager,
                                    handPoseManager: handPoseManager
                                )
                            }
                        }
                    }
            }
        }
        .tint(.appSecondaryText)
    }
}

#Preview {
    ContentView()
}
