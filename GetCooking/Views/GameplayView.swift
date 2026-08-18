//
//  GameplayView.swift
//  GetCooking
//
//  The 3-layer AR stack: camera feed, transparent SpriteKit scene,
//  and SwiftUI HUD.
//
//  HandPoseManager is handed in — the seat check before this screen is
//  already using the camera, and rebuilding the capture session here would
//  stall the app at the worst possible moment. GameStateManager is owned
//  here, so every run starts fresh.
//

import AVFoundation
import SpriteKit
import SwiftUI

struct GameplayView: View {
    @Bindable var sceneManager: SceneManager
    @ObservedObject var handPoseManager: HandPoseManager

    @StateObject private var gameStateManager = GameStateManager()

    @State private var scene = GameScene(size: CGSize(width: 1024, height: 768))
    @State private var showHandSkeleton = true

    /// Seconds left on the "get ready" beat, counting 3 → 1 and then 0 once
    /// play has begun. The board is already up and the camera live; the game
    /// state machine simply stays `.idle` until this reaches zero, so nothing
    /// spawns and no clock runs while the player settles.
    @State private var countdown = 3

    private var isCountingDown: Bool { countdown > 0 }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Camera comes from ContentView, already running.
                if showHandSkeleton {
                    BodySkeletonView(handPoseManager: handPoseManager)
                        .ignoresSafeArea()

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

                        // Hidden rather than removed during the countdown: it
                        // still holds its width, so the score and hearts don't
                        // jump sideways the moment the first recipe lands.
                        RecipeCard(recipe: gameStateManager.currentRecipe)
                            .opacity(isCountingDown ? 0 : 1)

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
                        sceneManager: sceneManager 
                    )
                }

                if isCountingDown {
                    GetReadyOverlay(count: countdown)
                        .ignoresSafeArea()
                }

                if handPoseManager.authorizationStatus == .denied
                    || handPoseManager.authorizationStatus == .restricted
                {
                    CameraPermissionDeniedOverlay()
                }
            }
            
        }

        .task {
            // The camera is already running, handed over by the seat check.
            for step in stride(from: 3, through: 1, by: -1) {
                countdown = step
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return // view went away mid-count
                }
            }
            countdown = 0
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
    GameplayView(sceneManager: SceneManager(), handPoseManager: HandPoseManager())
}
