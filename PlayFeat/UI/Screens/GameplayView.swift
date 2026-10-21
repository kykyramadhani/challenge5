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

    /// Forwarded by PlayFeatApp (PhoneSafeSides hosts the app separately, so
    /// the system value doesn't reach here on its own).
    @Environment(\.scenePhase) private var scenePhase

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

    /// The app went to the background mid-run. The player may have moved or
    /// put the iPad down, so coming back plays a fresh 3-2-1 before the clock
    /// restarts. A brief `.inactive` (Control Center, a banner) resumes at once.
    @State private var needsGetReadyOnReturn = false

    /// Bumped to run the 3-2-1 that resumes a paused run. 0 means none yet.
    @State private var resumeCountdownRequest = 0

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

    private var isCameraDenied: Bool {
        handPoseManager.authorizationStatus == .denied
            || handPoseManager.authorizationStatus == .restricted
    }

    /// The hidden Stop control is only live during actual play: the countdown
    /// and the game-over cover have their own flow.
    private var canStop: Bool {
        !isCountingDown && gameStateManager.state != .gameOver
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
            GameBoardView(
                scene: scene,
                showsBoard: boardIsUp,
                isRendering: scenePhase == .active
            )

            Group {
                if sceneManager.isInTutorial {
                    TutorialView { sceneManager.finishTutorial() }
                        .onAppear { handPoseManager.start() }
                }
                else {
                    if needsCalibration && !hasCalibrated {
                        SeatCalibrationView(handPoseManager: handPoseManager) {
                            // Whoever calibrated is the player for this run;
                            // anyone else who walks into shot is ignored.
                            handPoseManager.lockOntoPlayer()
                            hasCalibrated = true
                        } onBack: {
                            sceneManager.goToMainMenu()
                        }
                        .designScaled()
                    } else {
                        gameBody
                    }
                }
            }

            // Over the seat check and the board alike. Information only, so it
            // never takes the touches the Back and Stop controls need.
            if isCameraDenied {
                CameraPermissionDeniedOverlay()
                    .designScaled()
                    .allowsHitTesting(false)
            }

            #if DEBUG
            DebugSkeletonOverlay(handPoseManager: handPoseManager)
            #endif

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
            connectScene()
            handPoseManager.start()

            // Disables Auto-Lock Screen during Gameplay
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            handPoseManager.releasePlayer()
            handPoseManager.stop()
            UIApplication.shared.isIdleTimerDisabled = false
            audio.stopMusic()
        }
    }

    /// Hands the scene what it reads every frame. Done here because this
    /// screen owns all of it; GameBoardView only hosts and sizes the scene.
    private func connectScene() {
        scene.gameStateManager = gameStateManager
        scene.handInput = handPoseManager
        scene.audio = audio
    }

    private var gameBody: some View {
        GeometryReader { _ in
            ZStack {
                GameHUD(gameStateManager: gameStateManager, isCountingDown: isCountingDown)

                LoseHeartOverlay(gameStateManager: gameStateManager)

                if isCountingDown {
                    GetReadyOverlay(count: countdown)
                        .ignoresSafeArea()
                }

                if canStop {
                    StopButtonLayer(onStop: quitGame)
                }
            }
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
            // startMusic is a no-op if it's somehow already going.
            guard await playGetReadyCountdown() else { return }
            gameStateManager.start()
            audio.startMusic()
        }
        .task(id: resumeCountdownRequest) {
            // The app left mid-run and is back. Re-checked at the end: if it
            // left again during the count, the clock stays frozen.
            guard resumeCountdownRequest > 0,
                  await playGetReadyCountdown(),
                  scenePhase == .active else { return }
            gameStateManager.resume()
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
        .onChange(of: gameStateManager.isPaused) { _, _ in
            syncScenePause()
        }
        .onChange(of: gameStateManager.state) { _, state in
            syncScenePause()
            if state == .gameOver, !isEndingRun {
                showGameOver()
            }
        }
        .designScaled()
    }

    /// Plays the 3-2-1-GO! beat. False if it was cut short: the view went
    /// away, or a newer count replaced it.
    private func playGetReadyCountdown() async -> Bool {
        // One shot at the top of the beat — the clip already voices 3-2-1.
        audio.play(.countdown)
        for step in stride(from: 3, through: 0, by: -1) {
            countdown = step  // 0 is the "GO!" beat
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return false
            }
        }
        countdown = -1
        return true
    }

    /// The board freezes while the run is paused and once it is over.
    private func syncScenePause() {
        scene.isPaused = gameStateManager.isPaused || gameStateManager.state == .gameOver
    }

    // MARK: - Leaving and returning to the foreground

    /// PlayFeatApp stops hand tracking whenever the app isn't active, so the
    /// clock stops with it — at `.inactive` too, or a glance at Control Center
    /// could cost a life the player had no way to save.
    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            resumeRun()
        case .background:
            gameStateManager.pause()
            needsGetReadyOnReturn = gameStateManager.isPaused
        default:
            gameStateManager.pause()
        }
    }

    /// Picks the run back up: at once after a brief interruption, or after a
    /// fresh 3-2-1 if the player actually left the app. A resume count still
    /// running is left to finish.
    private func resumeRun() {
        guard gameStateManager.isPaused, !isCountingDown else { return }
        if needsGetReadyOnReturn {
            needsGetReadyOnReturn = false
            resumeCountdownRequest += 1
        } else {
            gameStateManager.resume()
        }
    }

    private func showGameOver() {
        isEndingRun = true
        audio.stopMusic()
        showGameOverCover = true
    }

    private func quitGame() {
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
