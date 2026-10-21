//
//  ProcurementWorktop.swift
//  PlayFeat
//
//  Everything that stands on the Procurement worktop over the camera feed:
//  sink, portals, table and cutting board, trash can, the three ingredient
//  crates and the tray bubble. Placed from ProcurementLayout, the same rects
//  the scene hit-tests hands against.
//

import SwiftUI

struct ProcurementWorktop: View {
    let game: ProcurementGame
    let layout: ProcurementLayout

    var body: some View {
        ZStack {
            furniture("KitchenSink", in: layout.sink)
            furniture("PortalFrontHouse", in: layout.frontHousePortal)
            furniture("PortalKitchen", in: layout.kitchenPortal)
            furniture("PrepTable", in: layout.table)
            cuttingBoard
            furniture("TrashCan", in: layout.trashCan)

            ForEach(game.cards.indices, id: \.self) { slot in
                IngredientCrate(ingredient: game.cards[slot])
                    .id(game.cards[slot])
                    .transition(.scale.combined(with: .opacity))
                    .placed(in: layout.card(slot), designSize: IngredientCrate.size)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: game.cards)

            if game.crew.dirtyTrays > 0 || game.cleanTraysReady > 0 {
                TrayBubble(dirtyTrays: game.crew.dirtyTrays, cleanTrays: game.cleanTraysReady)
                    .placed(in: layout.trayBubble,
                            designSize: CGSize(width: TrayBubble.size, height: TrayBubble.size))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: game.crew.dirtyTrays)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: game.cleanTraysReady)
    }

    private var cuttingBoard: some View {
        Image("CuttingBoard")
            .resizable()
            .overlay {
                if let sliced = game.slicedOnBoard {
                    IngredientArt(ingredient: sliced, size: layout.cuttingBoard.height * 0.8, isPrepared: true)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: layout.cuttingBoard.width, height: layout.cuttingBoard.height)
            .position(layout.cuttingBoard.center)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: game.slicedOnBoard)
    }

    private func furniture(_ image: String, in rect: CGRect) -> some View {
        Image(image)
            .resizable()
            .scaledToFit()
            .frame(width: rect.width, height: rect.height)
            .position(rect.center)
            .accessibilityHidden(true)
    }
}
