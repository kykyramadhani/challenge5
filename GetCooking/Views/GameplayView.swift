//
//  GameplayView.swift
//  GetCooking
//
//  The 3-layer AR stack: camera feed, transparent SpriteKit scene,
//  and SwiftUI HUD. Owns HandPoseManager and GameStateManager for
//  the duration of a play session — both are recreated fresh each
//  time the player starts a new game from the main menu.
//

import SwiftUI
import SpriteKit
import AVFoundation

struct GameplayView: View {
    @ObservedObject var sceneManager: SceneManager
    @StateObject private var handPoseManager = HandPoseManager()
    @StateObject private var gameStateManager = GameStateManager()
    @State private var scene = GameScene(size: CGSize(width: 1024, height: 768))
    @State private var showHandSkeleton = true

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Layer 1 — camera feed
                CameraPreviewView(handPoseManager: handPoseManager)
                    .ignoresSafeArea()

                // Layer 1.5 — live hand skeleton, painted onto the camera feed.
                // Set `showHandSkeleton = false` to hide it during real play.
                if showHandSkeleton {
                    HandSkeletonView(handPoseManager: handPoseManager)
                        .ignoresSafeArea()
                }
                
                SpriteView(scene: scene, options: [.allowsTransparency, .ignoresSiblingOrder])
                    .ignoresSafeArea()
                    .background(.clear)
                    .onAppear {
                        scene.size = proxy.size
                        scene.gameStateManager = gameStateManager
                        scene.handPoseManager = handPoseManager
                    }
                    .onChange(of: proxy.size) { _, newSize in
                        scene.size = newSize
                    }

                VStack {
                    HStack(alignment: .top) {
                        RecipeCardView(recipe: gameStateManager.currentRecipe)
                        Spacer(minLength: 12)
                        HStack(spacing: 8) {
                            StatBadge(icon: "star.fill", value: "\(gameStateManager.score)")
                            StatBadge(
                                icon: "timer",
                                value: "\(gameStateManager.remainingTime)",
                                tint: gameStateManager.remainingTime <= 10 ? .red : .primary
                            )
                            PauseButton(isPaused: gameStateManager.isPaused) {
                                gameStateManager.togglePause()
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    Spacer()
                }

                if gameStateManager.state == .gameOver {
                    PostGame(
                        score: gameStateManager.score,
                        onRestart: { gameStateManager.restart() },
                        onMainMenu: { sceneManager.goToMainMenu() }
                    )
                }

                if handPoseManager.authorizationStatus == .denied
                    || handPoseManager.authorizationStatus == .restricted {
                    CameraPermissionDeniedOverlay()
                }
            }
        }
        .onAppear {
            handPoseManager.start()
            gameStateManager.start()
        }
        .onDisappear {
            handPoseManager.stop()
        }
        .onChange(of: gameStateManager.isPaused) { _, paused in
            scene.isPaused = paused
        }
        .onChange(of: gameStateManager.state) { _, state in
            scene.isPaused = (state == .gameOver)
            }
        }
    }
}
