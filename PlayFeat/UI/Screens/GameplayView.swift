//
//  GameplayView.swift
//  PlayFeat
//
//  Owns the whole in-game flow: tutorial, then the seat check, then the
//  3-layer AR stack — camera feed, transparent SpriteKit scene, and SwiftUI HUD.
//
//  The tutorial and seat check run here as internal phases rather than as
//  their own AppScreens. The view swaps its *own* content from the seat check
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
    
    @State private var gameStateManager: GameStateManager
    
    var handPoseManager: HandPoseManager
    
    private let audio: AudioManager

    init(sceneManager: SceneManager,
         handPoseManager: HandPoseManager,
         inventory: InventoryManager,
         audio: AudioManager) {
        self.sceneManager = sceneManager
        self.handPoseManager = handPoseManager
        self.audio = audio
        let game = GameStateManager(inventory: inventory)
        GameAudio.attach(to: game, sounds: audio)
        _gameStateManager = State(initialValue: game)
    }

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

    /// True while the "Game Over" cover is playing, between the run ending and
    /// the results screen taking over. The board underneath is already frozen.
    @State private var showGameOverCover = false

    /// Guards the game-over hand-off so a repeated `.gameOver` never stacks a
    /// second cover or fires the navigation twice.
    @State private var isEndingRun = false

    /// Where the "get ready" beat has got to: 3 → 2 → 1 → 0, where 0 is the
    /// "GO!" flash, and -1 once it is over and the overlay is gone. The board
    /// is already up and the camera live throughout; the game state machine
    /// simply stays `.idle` until the countdown finishes, so nothing spawns
    /// and no clock runs while the player settles.
    @State private var countdown = 3

    private var isCountingDown: Bool { countdown >= 0 }

    /// Every run starts with a seat check, except the DEBUG launch shortcut
    /// that drops straight onto the board.
    private var needsCalibration: Bool {
        #if DEBUG
        if DebugLaunch.skipToGameplay { return false }
        #endif
        return true
    }
    
    /// The seat check is done (or was never needed), so the playfield belongs
    /// on screen. Until then only the hand glow is drawn.
    private var boardIsUp: Bool {
        !sceneManager.isInTutorial && (hasCalibrated || !needsCalibration)
    }

    var body: some View {
        ZStack {
            // Backmost layer for the whole screen. It sits *outside* the Group
            // below, so it stays mounted across the seat-check → board swap —
            // no camera re-mount, no re-created capture session (that's owned by
            // HandPoseManager). Both the seat check and the board draw over it.
            CameraPreviewView(camera: handPoseManager.camera)
                .ignoresSafeArea()

            // Mounted here rather than inside `gameBody` so the scene is alive
            // for the whole screen, seat check included. The hand glow lives in
            // the scene, and the player should see their hands light up the
            // moment they are detected — during calibration and the countdown,
            // not only once play starts. `showsBoard` keeps the plate and bin
            // out of sight until then.
            sceneLayer

            Group {
                if sceneManager.isInTutorial {
                    TutorialView { sceneManager.finishTutorial() }
                        .onAppear { handPoseManager.start() }
                }
                else {
                    if needsCalibration && !hasCalibrated {
                        SeatCalibrationView(handPoseManager: handPoseManager) {
                            hasCalibrated = true
                        }
                        .designScaled()
                    } else {
                        gameBody
                    }
                }
            }

            // The run-over cover. Sits above the whole stack so it dims the
            // board, the HUD and the hand glow alike. It owns its own timing
            // and calls back when it is done, at which point the results screen
            // is shown (which unmounts this view and the cover with it).
            if showGameOverCover {
                GameOverOverlay {
                    sceneManager.goToPostGame(gameStateManager.result)
                }
                .designScaled()
                .zIndex(200)
            }
        }
        // The capture session is started when this screen appears and stopped
        // when the player leaves gameplay entirely. start() is idempotent, so
        // the seat check and board calling it again is harmless; the preview
        // above stays live across their swap because it never leaves the tree.
        .onAppear {
            handPoseManager.start()
            
            // Disables Auto-Lock Screen during Gameplay
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            handPoseManager.stop()
            UIApplication.shared.isIdleTimerDisabled = false
            audio.stopMusic()
        }
    }

    /// The SpriteKit layer: the board during play, and the hand glow at all
    /// times. Kept out of `gameBody` so the seat check draws over a live scene
    /// rather than swapping one in afterwards.
    private var sceneLayer: some View {
        GeometryReader { proxy in
            SpriteView(
                scene: scene,
                options: [
                    .allowsTransparency, .ignoresSiblingOrder,
                ]
            )
            .background(.clear)
            .onAppear {
                scene.size = proxy.size
                scene.gameStateManager = gameStateManager
                scene.handInput = handPoseManager
                scene.showsBoard = boardIsUp
                scene.audio = audio
            }
            .onChange(of: proxy.size) { _, newSize in
                scene.size = newSize
            }
            .onChange(of: boardIsUp) { _, isUp in
                scene.showsBoard = isUp
            }
        }
        .ignoresSafeArea()
    }

    private var gameBody: some View {
        GeometryReader { proxy in
            ZStack {
                VStack {
                    HStack(alignment: .center) {

                        Spacer()

                        PointCard(
                            dishesServed: gameStateManager.dishesCompleted
                        )

                        Spacer()

                        // Hidden rather than removed during the countdown: it
                        // still holds its width, so the score and hearts don't
                        // jump sideways the moment the first recipe lands.
                        RecipeCard(
                            recipe: gameStateManager.currentRecipe,
                            gameStateManager: gameStateManager
                        )
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
                
                LoseHeartOverlay(gameStateManager: gameStateManager)

                if isCountingDown {
                    GetReadyOverlay(count: countdown)
                        .ignoresSafeArea()
                }

                if handPoseManager.authorizationStatus == .denied
                    || handPoseManager.authorizationStatus == .restricted
                {
                    CameraPermissionDeniedOverlay()
                }

                // Hidden quit control. User tap the screen toggle the Stop Button
                if !isCountingDown && gameStateManager.state != .gameOver {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showStopButton.toggle()
                            }
                        }

                    if showStopButton {
                        // Bottom Left Button
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
        .task(id: gameStateManager.runNumber) {
            // Runs when the board appears — i.e. after calibration — and again
            // on every replay, keyed off runNumber since a replay that skips
            // calibration (no calibration required) never remounts this view.
            // A life lost mid-run doesn't change runNumber: that wipes the
            // board too, but a countdown there would interrupt play the player
            // hasn't lost yet.
            // The camera is already live, handed over by the seat check.
            // Bring the music up under the count so play starts already scored;
            // startMusic is a no-op if it's somehow already going.

            // One shot at the top of the beat — the clip already voices 3-2-1.
            audio.play(.countdown)
            for step in stride(from: 3, through: 0, by: -1) {
                countdown = step  // 0 is the "GO!" beat
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return  // view went away mid-count
                }
            }
            countdown = -1
            gameStateManager.start()
            audio.startMusic()
        }
        .onChange(of: gameStateManager.isPaused) { _, paused in
            scene.isPaused = paused
            // Hold the music with the game so a pause is actually quiet.
            if paused { audio.pauseMusic() }
            else { audio.resumeMusic() }
        }
        .onChange(of: gameStateManager.state) { _, state in
            scene.isPaused = (state == .gameOver)
            
            if state == .gameOver, !isEndingRun {
                showGameOver()
            }
        }
        .designScaled()
    }
    
    private func showGameOver() {
        isEndingRun = true
        audio.stopMusic()
        showGameOverCover = true
    }

    private func quitGame() {
        showStopButton = false
        gameStateManager.gameOver()
        showGameOver()
    }
}

#Preview {
    // One instance for both: the view's own calls and its child buttons
    // must share the same AudioManager.
    let audio = AudioManager()
    return GameplayView(
        sceneManager: SceneManager(),
        handPoseManager: HandPoseManager(),
        inventory: InventoryManager(inMemory: true),
        audio: audio
    )
    .environment(audio)
}
