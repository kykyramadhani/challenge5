//
//  CuttingPanel.swift
//  PlayFeat
//
//  The cutting board zoomed in. The two lanes show the bare-hand motion —
//  one hand down, the other up, like a handshake — and the ingredient on the
//  board moves through its cut stages as ProcurementGame counts real chops.
//

import SwiftUI

struct CuttingPanel: View {
    let ingredient: KitchenIngredient
    let chops: Int

    private let boardSize = CGSize(width: 680, height: 430)

    var body: some View {
        WorkstationPanel {
            Image("CuttingBoard")
                .resizable()
                .frame(width: boardSize.width, height: boardSize.height)
                .overlay { stageArt.frame(width: 300, height: 300) }
                .offset(x: 197, y: 202)

            ChopLane(pointsUp: false).offset(x: 301, y: 191)
            ChopLane(pointsUp: true).offset(x: 683, y: 190)

            PanelProgressBar(progress: Double(chops) / Double(ProcurementGame.chopsNeeded),
                             segments: ProcurementGame.chopsNeeded)
                .offset(x: 247, y: 669)
        }
    }

    /// The Figma ingredient sheet's cut stages: whole, first cut, second cut,
    /// sliced. Only the mushroom has them; anything else shows as it is.
    @ViewBuilder private var stageArt: some View {
        let stages = ["MushroomRaw", "MushroomCut1", "MushroomCut2", "MushroomSliced"]
        if ingredient == .glowingMushroom {
            let name = stages[min(chops, stages.count - 1)]
            Image(name)
                .resizable()
                .scaledToFit()
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: chops)
        } else {
            IngredientArt(ingredient: ingredient, size: 300, isPrepared: chops >= ProcurementGame.chopsNeeded)
        }
    }
}

/// A shaded lane with a dashed arrow: the path one hand should follow.
private struct ChopLane: View {
    let pointsUp: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 48)
            .fill(.laneShade.opacity(0.17))
            .frame(width: 94, height: 465)
            .overlay {
                Image("ChopPatternArrow")
                    .resizable()
                    .frame(width: 50.7, height: 409)
                    .rotationEffect(.degrees(pointsUp ? 180 : 0))
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    CuttingPanel(ingredient: .glowingMushroom, chops: 1)
        .scaleEffect(0.6)
}
