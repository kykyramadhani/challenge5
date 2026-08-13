//
//  ContentView.swift
//  VisionChef
//
//  The mandated 3-layer AR stack:
//    Layer 1 (back)   CameraPreviewView — front-camera passthrough
//    Layer 2 (middle) transparent SpriteView (the game)
//    Layer 3 (front)  SwiftUI HUD — recipe, score, timer, pause, permission
//
//  HandPoseManager and GameStateManager are owned here and injected into the
//  scene. The camera preview shares HandPoseManager's session.
//

import SwiftUI
import SpriteKit
import AVFoundation

struct ContentView: View {
    @StateObject private var handPoseManager = HandPoseManager()
    @StateObject private var gameStateManager = GameStateManager()
    @State private var scene = GameScene(size: CGSize(width: 1024, height: 768))

    /// Debug overlay showing what Vision is tracking.
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

                // Layer 2 — transparent game scene
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

                // Layer 3 — HUD. No panel behind it: the camera feed is the
                // game board, so anything opaque up here breaks the illusion.
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
                            // Debug affordance: A/B the widest framing against
                            // a conventional 1× crop while playing.
                            Button {
                                handPoseManager.toggleFieldOfView()
                            } label: {
                                StatBadge(icon: "camera.viewfinder",
                                          value: handPoseManager.fieldOfView.label)
                            }
                            .buttonStyle(.plain)

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
                    GameOverCard(score: gameStateManager.score) {
                        gameStateManager.restart()
                    }
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
        // Swipes are consumed by GameScene, not here: deciding whether a
        // downward flick is a discard or a drop needs the plate's position and
        // the grab state of the hand that made it.
        // Freeze the physics/drag scene whenever the game is paused or over.
        .onChange(of: gameStateManager.isPaused) { _, paused in
            scene.isPaused = paused
        }
        .onChange(of: gameStateManager.state) { _, state in
            scene.isPaused = (state == .gameOver)
        }
    }
}

#Preview {
    ContentView()
}
