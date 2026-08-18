//
//  GameplayView.swift
//  GetCooking
//
//  Owns the whole in-game flow: first the seat check (for games that need it),
//  then the 3-layer AR stack — camera feed, transparent SpriteKit scene, and
//  SwiftUI HUD.
//
//  The seat check runs here as an internal phase rather than as its own
//  navigation destination. That keeps a single, stable "gameplay" destination
//  in the NavigationStack: the view swaps its *own* content from the seat check
//  to the board once calibration passes, so the camera never re-mounts and the
//  countdown's `.task` fires exactly once, when the board actually appears.
//
//  HandPoseManager is handed in — the seat check is already using the camera,
//  and rebuilding the capture session here would stall the app at the worst
//  possible moment. GameStateManager is owned here, so every run starts fresh.
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

    /// Flips once the player has passed the seat check. Local to this view, so
    /// navigation state (SceneManager) stays purely about *which screen*, not
    /// *how far into the screen* the player is.
    @State private var hasCalibrated = false

    /// Seconds left on the "get ready" beat, counting 3 → 1 and then 0 once
    /// play has begun. The board is already up and the camera live; the game
    /// state machine simply stays `.idle` until this reaches zero, so nothing
    /// spawns and no clock runs while the player settles.
    @State private var countdown = 3

    private var isCountingDown: Bool { countdown > 0 }

    /// The selected game asks for a seat check and the player hasn't passed it
    /// yet. Games without calibration skip straight to the board.
    private var needsCalibration: Bool {
        sceneManager.selectedGame?.requiresCalibration ?? false
    }

    var body: some View {
        ZStack {
            // Backmost layer for the whole screen. It sits *outside* the Group
            // below, so it stays mounted across the seat-check → board swap —
            // no camera re-mount, no re-created capture session (that's owned by
            // HandPoseManager). Both the seat check and the board draw over it.
            CameraPreviewView(handPoseManager: handPoseManager)
                .ignoresSafeArea()

            // Camera comes from ContentView, already running.
            if showHandSkeleton {
                BodySkeletonView(handPoseManager: handPoseManager)
                    .ignoresSafeArea()

                HandSkeletonView(handPoseManager: handPoseManager)
                    .ignoresSafeArea()
            }

            Group {
                if sceneManager.isInTutorial {
                    TutorialView { sceneManager.finishTutorial() }
                        .onAppear { handPoseManager.start() }
                } else {
                    if needsCalibration && !hasCalibrated {
                        SeatCalibrationView(handPoseManager: handPoseManager) {
                            hasCalibrated = true
                        }
                    } else {
                        gameBody
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        // The capture session is started when this screen appears and stopped
        // when the player leaves gameplay entirely. start() is idempotent, so
        // the seat check and board calling it again is harmless; the preview
        // above stays live across their swap because it never leaves the tree.
        .onAppear { handPoseManager.start() }
        .onDisappear { handPoseManager.stop() }
    }

    private var gameBody: some View {
        GeometryReader { proxy in
            ZStack {
                SpriteView(
                    scene: scene,
                    options: [
                        .allowsTransparency, .ignoresSiblingOrder,
                    ]
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
        .onAppear {
            // Idempotent: for a game that skipped calibration this actually
            // starts the session; after a seat check it just confirms it's
            // still running.
            handPoseManager.start()
        }
        .task {
            // Runs when the board appears — i.e. after calibration. The camera
            // is already live, handed over by the seat check.
            for step in stride(from: 3, through: 1, by: -1) {
                countdown = step
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return  // view went away mid-count
                }
            }
            countdown = 0
            gameStateManager.start()
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
    GameplayView(
        sceneManager: SceneManager(),
        handPoseManager: HandPoseManager()
    )
}
