//
//  KitchenShiftView.swift
//  PlayFeat
//
//  The frame every role's shift is played in, back to front: the live
//  camera, the role's worktop, the order rail and shift clock, a zoomed-in
//  panel when one is open, and on top the SpriteKit layer with the purple
//  hand glow and whatever the hands carry — above the panels, so the player
//  can always see where their hands are.
//
//  A shift opens on the seat check over the live camera, which picks the
//  player and locks the hand pipeline onto them, then a 3-2-1: the shift (and
//  its order clocks) only starts once the count is over and the camera is
//  delivering frames. The camera session belongs to HandPoseManager and is
//  only started and stopped here.
//

import AVFoundation
import SpriteKit
import SwiftUI

struct KitchenShiftView<Layout: KitchenLayout, Worktop: View, Rail: View, Panel: View>: View {
    var sceneManager: SceneManager
    var handPoseManager: HandPoseManager
    let audio: AudioManager
    let shift: KitchenShift
    let scene: KitchenScene
    /// Whether the role has a zoomed-in panel open over its worktop.
    let isPanelOpen: Bool
    @ViewBuilder let worktop: (Layout) -> Worktop
    /// The order tickets along the top.
    @ViewBuilder let rail: (Layout) -> Rail
    @ViewBuilder let panel: () -> Panel

    @State private var showShiftOver = false
    @State private var phase = ShiftPhase.opening(withSeatCheck: Self.hasSeatCheck)
    /// The number on the countdown screen.
    @State private var countdownNumber = ShiftCountdown.firstNumber
    @State private var isWaitingForCamera = false

    var body: some View {
        GeometryReader { proxy in
            let layout = Layout(size: proxy.size)
            ZStack {
                cameraLayer
                switch phase {
                case .seatCheck:
                    seatCheck
                case .countdown:
                    ShiftCountdownOverlay(number: isCameraBlocked ? nil : countdownNumber,
                                          isCameraLive: handPoseManager.isReceivingFrames,
                                          isWaitingForCamera: isWaitingForCamera)
                case .playing:
                    kitchen(layout, size: proxy.size)
                }
                cameraPermissionNotice
                shiftOverCover
            }
        }
        .ignoresSafeArea()
        .onAppear(perform: startCamera)
        .task(id: phase) {
            if phase == .countdown { await countDownThenPlay() }
        }
        .onDisappear(perform: endShift)
        .onChange(of: shift.lives) { old, new in if new < old { audio.play(.loseHeart) } }
        .onChange(of: shift.ordersServed) { audio.play(.putOrder) }
        .onChange(of: shift.isActiveOrderRunningLow) { _, isLow in
            if isLow { audio.startClockWarning() } else { audio.stopClockWarning() }
        }
        .onChange(of: shift.isOver) { _, isOver in
            guard isOver else { return }
            audio.stopClockWarning()
            audio.stopMusic()
            showShiftOver = true
        }
    }

    // MARK: - Layers

    /// Laid out at the real screen size, not the design canvas, so its frame
    /// lines up with the player's body on the full-screen camera feed.
    private var seatCheck: some View {
        SeatCalibrationView(handPoseManager: handPoseManager) {
            // Whoever passed the check is the player for this shift; anyone
            // else who walks into shot is ignored until it ends.
            handPoseManager.lockOntoPlayer()
            phase = phase.next
        } onBack: {
            sceneManager.goToRoleSelect()
        }
    }

    @ViewBuilder
    private func kitchen(_ layout: Layout, size: CGSize) -> some View {
        worktop(layout)
        rail(layout)
        ShiftClockCard(elapsedSeconds: shift.elapsedSeconds, lives: shift.lives,
                       startingLives: KitchenShift.startingLives)
            .placed(in: layout.shiftClock, designSize: ShiftClockCard.size)
        panelLayer(layout)
        sceneLayer(size: size)
    }

    /// The live feed. The gray behind it is Figma's stand-in for the camera,
    /// and what shows while the camera starts or when there is none.
    private var cameraLayer: some View {
        ZStack {
            Color(white: 0.6)
            CameraPreviewView(camera: handPoseManager.camera)
        }
    }

    @ViewBuilder
    private func panelLayer(_ layout: Layout) -> some View {
        if isPanelOpen {
            ZStack {
                Color.white.opacity(0.6)
                panel()
                    .placed(in: layout.panel, designSize: WorkstationPanel<EmptyView>.size)
            }
            .transition(.scale(scale: 0.4).combined(with: .opacity))
        }
    }

    private func sceneLayer(size: CGSize) -> some View {
        SpriteView(scene: scene, options: [.allowsTransparency, .ignoresSiblingOrder])
            .onAppear {
                scene.size = size
                scene.handInput = handPoseManager
                scene.audio = audio
            }
            .onChange(of: size) { _, newSize in scene.size = newSize }
            #if !targetEnvironment(simulator)
            // On a device only hands play; touches pass through. The simulator
            // has no camera, so there a finger stands in for a hand.
            .allowsHitTesting(false)
            #endif
    }

    /// Information only, under the panels; it must not swallow the touches
    /// the simulator uses in place of hands.
    @ViewBuilder
    private var cameraPermissionNotice: some View {
        if isCameraBlocked {
            CameraPermissionDeniedOverlay()
                .designScaled()
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var shiftOverCover: some View {
        if showShiftOver {
            GameOverOverlay { sceneManager.goToRoleSelect() }
                .designScaled()
                .zIndex(200)
        }
    }

    // MARK: - Camera readiness

    /// Only with a real camera to check against. The simulator has none (a
    /// finger stands in for a hand), and the DEBUG shortcut drops straight
    /// into play.
    private static var hasSeatCheck: Bool {
        #if targetEnvironment(simulator)
        false
        #elseif DEBUG
        !DebugLaunch.skipToGameplay
        #else
        true
        #endif
    }

    /// Camera access was refused. Never true on the simulator, which doesn't
    /// use the camera, so isn't asked for it.
    private var isCameraBlocked: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        handPoseManager.authorizationStatus == .denied || handPoseManager.authorizationStatus == .restricted
        #endif
    }

    /// The simulator has no camera to track hands with — touches stand in for
    /// them there — so it never waits for one.
    private var isCameraReady: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        handPoseManager.isReceivingFrames
        #endif
    }

    // MARK: - Lifecycle

    /// Starts the camera first thing, so it warms up behind the countdown.
    private func startCamera() {
        #if !targetEnvironment(simulator)
        handPoseManager.start()
        #endif
        UIApplication.shared.isIdleTimerDisabled = true
    }

    /// Runs the 3-2-1, holding on 1 for as long as the camera isn't ready
    /// (or is blocked), then starts the shift. Cancelled with the view.
    private func countDownThenPlay() async {
        audio.play(.countdown)
        let start = Date.now
        while let number = ShiftCountdown.number(after: Date.now.timeIntervalSince(start),
                                                 isCameraReady: isCameraReady) {
            if countdownNumber != number { countdownNumber = number }
            isWaitingForCamera = Date.now.timeIntervalSince(start) >= ShiftCountdown.duration
            do {
                try await Task.sleep(for: .milliseconds(50))
            } catch {
                return
            }
        }
        shift.start()
        audio.startMusic()
        phase = phase.next
    }

    private func endShift() {
        shift.stop()
        handPoseManager.releasePlayer()
        handPoseManager.stop()
        audio.stopClockWarning()
        audio.stopMusic()
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
