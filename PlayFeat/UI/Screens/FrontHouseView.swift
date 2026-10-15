//
//  FrontHouseView.swift
//  PlayFeat
//
//  The Front House shift: the counter and the zoomed-in dispenser, in the
//  shared KitchenShiftView frame (camera, countdown, clock, hands), with its
//  own tray tickets. FrontHouseGame is created here, so every shift starts
//  fresh.
//

import SwiftUI

struct FrontHouseView: View {
    var sceneManager: SceneManager
    var handPoseManager: HandPoseManager
    let audio: AudioManager

    @State private var game = FrontHouseGame(mode: .playtest)
    @State private var scene = FrontHouseScene(size: FrontHouseLayout.figmaSize)

    var body: some View {
        KitchenShiftView(sceneManager: sceneManager, handPoseManager: handPoseManager, audio: audio,
                         shift: game.shift, scene: scene, isPanelOpen: game.station == .pouring) {
            (layout: FrontHouseLayout) in FrontHouseWorktop(game: game, layout: layout)
        } rail: {
            FrontHouseRail(shift: game.shift, layout: $0)
        } panel: {
            DispenserPanel(progress: game.fill, isTapOpen: game.isTapOpen)
        }
        .onAppear { scene.game = game }
        .onChange(of: game.traysOnTable) { old, new in
            if new > old { audio.play(.bell) }
        }
    }
}
