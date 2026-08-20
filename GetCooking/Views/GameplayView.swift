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
import UIKit

struct GameplayView: View {
    @Bindable var sceneManager: SceneManager
    @ObservedObject var handPoseManager: HandPoseManager

    @StateObject private var gameStateManager = GameStateManager()

    @State private var scene = GameScene(size: CGSize(width: 1024, height: 768))
    @State private var showHandSkeleton = true

    /// The quit control is normally invisible — the board is played with hands,
    /// not touch, so a stray tap shouldn't do anything. Tapping the screen once
    /// flips this on to reveal a Stop button; tapping away (or waiting a few
    /// seconds) hides it again. This keeps a bail-out reachable during play
    /// without putting a permanent button over the camera feed.
    @State private var showStopButton = false

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
        .onAppear {
            handPoseManager.start()
            // The game is played hands-free — no taps to keep the system's
            // auto-lock timer from firing — so without this the screen dims
            // and locks itself mid-round.
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            handPoseManager.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
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
                        onRestart: replay,
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

                // Hidden quit control. Only live during actual play — the
                // countdown and game-over screen have their own flow and
                // shouldn't be interruptible this way.
                if !isCountingDown && gameStateManager.state != .gameOver {
                    // Full-screen invisible tap catcher. A tap toggles the Stop
                    // button; when the button is showing, a tap that lands
                    // *outside* it falls through to here and dismisses it.
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showStopButton.toggle()
                            }
                        }

                    if showStopButton {
                        // Top-left corner, clear of the score / recipe / hearts
                        // HUD that runs across the top-center of the screen.
                        VStack {
                            Spacer()
                            HStack {
                                ButtonComponent(
                                    name: "Stop",
                                    icon: "xmark",
                                    action: quitGame,
                                    buttonStyle: .primary
                                )
                                .padding(40)

                                Spacer()
                            }
                        }
                        .transition(.opacity)
                    }
                }
            }
        }
        // Auto-hide the Stop button so a forgotten tap doesn't leave it sitting
        // over the feed; each fresh reveal restarts the countdown via the id.
        .task(id: showStopButton) {
            guard showStopButton else { return }
            try? await Task.sleep(for: .seconds(5))
            withAnimation(.easeInOut(duration: 0.2)) { showStopButton = false }
        }
        .onAppear {
            // Idempotent: for a game that skipped calibration this actually
            // starts the session; after a seat check it just confirms it's
            // still running.
            handPoseManager.start()
        }
        .task(id: gameStateManager.resetToken) {
            // Runs when the board appears — i.e. after calibration — and again
            // on every replay, keyed off resetToken since a replay that skips
            // calibration (no calibration required) never remounts this view.
            // The camera is already live, handed over by the seat check.
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

    /// Play Again: send the player back through the seat check (if the game
    /// needs one) and the countdown, exactly like the first run. Flipping
    /// `hasCalibrated` back swaps the Group to SeatCalibrationView, which
    /// unmounts `gameBody` — so its `.task` reruns fresh once calibration
    /// passes and the board reappears; for a game with no calibration step,
    /// `gameBody` never unmounts, so the `.task(id:)` keyed on `resetToken` is
    /// what reruns the countdown instead.
    private func replay() {
        if needsCalibration { hasCalibrated = false }
        gameStateManager.restart()
    }

    /// Bail out of the run entirely and go back to the main menu. Resetting the
    /// navigation path tears down GameplayView, whose `.onDisappear` stops the
    /// capture session; GameStateManager is owned here, so nothing carries over.
    private func quitGame() {
        showStopButton = false
        sceneManager.goToMainMenu()
    }
}

#Preview {
    GameplayView(
        sceneManager: SceneManager(),
        handPoseManager: HandPoseManager()
    )
}
