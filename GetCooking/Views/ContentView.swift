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

import SwiftUI

struct ContentView: View {
    @State private var sceneManager = SceneManager()
    @StateObject private var handPoseManager = HandPoseManager()

    private var showsCamera: Bool { sceneManager.currentScreen != .mainMenu }

    var body: some View {
        ZStack {
            // Mounted once and left alone across the seat check → game
            // handover. Handing a live AVCaptureSession to a freshly built
            // preview layer blocks the main thread, and doing that at exactly
            // the moment the game screen is being built is what froze the app
            // before the countdown.
            if showsCamera {
                CameraPreviewView(handPoseManager: handPoseManager)
                    .ignoresSafeArea()
            }

            switch sceneManager.currentScreen {
            case .mainMenu:
                MainMenuView { sceneManager.startGame() }
                    .onAppear { handPoseManager.stop() }

            case .calibration:
                SeatCalibrationView(handPoseManager: handPoseManager) {
                    sceneManager.beginPlaying()
                }

            case .game:
                GameplayView(sceneManager: sceneManager, handPoseManager: handPoseManager)
            }
        }
    }
}

#Preview {
    ContentView()
}
