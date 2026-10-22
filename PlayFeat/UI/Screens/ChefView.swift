//
//  ChefView.swift
//  PlayFeat
//
//  The Chef shift: the kitchen and the zoomed-in broth pot, in the shared
//  KitchenShiftView frame (camera, countdown, order rail, clock, hands).
//  ChefGame is created here, so every shift starts fresh.
//

import SwiftUI

struct ChefView: View {
    var sceneManager: SceneManager
    var handPoseManager: HandPoseManager
    let audio: AudioManager

    @State private var game = ChefGame(mode: .playtest)
    @State private var scene = ChefScene(size: ChefLayout.figmaSize)

    var body: some View {
        KitchenShiftView(sceneManager: sceneManager, handPoseManager: handPoseManager, audio: audio,
                         shift: game.shift, scene: scene, isPanelOpen: game.station == .stirring,
                         report: { game.report }) {
            (layout: ChefLayout) in ChefWorktop(game: game, layout: layout)
        } rail: {
            OrderRail(shift: game.shift, layout: $0)
        } panel: {
            SoupPanel(progress: game.stirProgress)
        }
        .onAppear { scene.game = game }
        .onChange(of: game.readyDishCount) { old, new in
            if new > old { audio.play(.bell) }
        }
    }
}
