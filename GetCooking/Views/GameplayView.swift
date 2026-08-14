//
//  GameplayView.swift
//  GetCooking
//
//  The 3-layer AR stack: camera feed, transparent SpriteKit scene,
//  and SwiftUI HUD. Owns HandPoseManager and GameStateManager for
//  the duration of a play session — both are recreated fresh each
//  time the player starts a new game from the main menu.
//

import AVFoundation
import SpriteKit
import SwiftUI

struct GameplayView: View {
    @Bindable var sceneManager: SceneManager

    @StateObject private var handPoseManager = HandPoseManager()
    @StateObject private var gameStateManager = GameStateManager()

    @State private var scene = GameScene(size: CGSize(width: 1024, height: 768))
    @State private var showHandSkeleton = true

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CameraPreviewView(handPoseManager: handPoseManager)
                    .ignoresSafeArea()

                if showHandSkeleton {
                    HandSkeletonView(handPoseManager: handPoseManager)
                        .ignoresSafeArea()
                }

                SpriteView(
                    scene: scene,
                    options: [
                        .allowsTransparency, .ignoresSiblingOrder]
                )
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
                    HStack(alignment: .center) {

                        Spacer()

                        PointCard(score: gameStateManager.score)

                        Spacer()

                        RecipeCard(recipe: gameStateManager.currentRecipe)

                        Spacer()

                        HeartCard(
                            hearts: gameStateManager.lives,
                            total: gameStateManager.startingLives
                        )

                        Spacer()
                    }

                    Spacer()
                }
                    .ignoresSafeArea()

                if gameStateManager.state == .gameOver {
                    PostGame(
                        score: gameStateManager.score,
                        survivedSeconds: gameStateManager.elapsedTime,
                        onRestart: { gameStateManager.restart() },
                        onMainMenu: { sceneManager.goToMainMenu() }
                    )
                }

                if handPoseManager.authorizationStatus == .denied
                    || handPoseManager.authorizationStatus == .restricted
                {
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

#Preview {
    GameplayView(sceneManager: SceneManager.init())
}
