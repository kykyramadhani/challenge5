//
//  ProcurementView.swift
//  PlayFeat
//
//  The Procurement shift: its worktop and its cutting and washing panels, in
//  the shared KitchenShiftView frame (camera, countdown, order rail, clock,
//  hands). ProcurementGame is created here, so every shift starts fresh.
//

import SwiftUI

struct ProcurementView: View {
    var sceneManager: SceneManager
    var handPoseManager: HandPoseManager
    let audio: AudioManager

    @State private var game = ProcurementGame(mode: .playtest)
    @State private var scene = ProcurementScene(size: ProcurementLayout.figmaSize)

    var body: some View {
        KitchenShiftView(sceneManager: sceneManager, handPoseManager: handPoseManager, audio: audio,
                         shift: game.shift, scene: scene, isPanelOpen: game.station != .worktop,
                         report: { game.report }) {
            (layout: ProcurementLayout) in ProcurementWorktop(game: game, layout: layout)
        } rail: {
            OrderRail(shift: game.shift, layout: $0)
        } panel: {
            stationPanel
        }
        .onAppear { scene.game = game }
    }

    @ViewBuilder
    private var stationPanel: some View {
        switch game.station {
        case let .cutting(ingredient):
            CuttingPanel(ingredient: ingredient, chops: game.chops)
        case .washing:
            WashingPanel(progress: game.washProgress)
        case .worktop:
            EmptyView()
        }
    }
}
