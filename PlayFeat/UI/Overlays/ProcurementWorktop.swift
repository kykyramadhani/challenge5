//
//  ProcurementWorktop.swift
//  PlayFeat
//
//  Everything that stands on the Procurement worktop over the camera feed:
//  sink, portals, table and cutting board, trash can, the three ingredient
//  crates (and their bubbles, wherever the player left them) and the
//  dirty-tray bubble — and each washed tray floating off to the Front House
//  portal. Placed from ProcurementLayout, the same rects the
//  scene hit-tests hands against.
//

import SwiftUI

struct ProcurementWorktop: View {
    let game: ProcurementGame
    let layout: ProcurementLayout

    /// 0 at the tray bubble, 1 at the Front House portal, while a washed
    /// tray floats away.
    @State private var cleanTrayFlight: CGFloat?

    var body: some View {
        ZStack {
            furniture("KitchenSink", in: layout.sink)
            furniture("PortalFrontHouse", in: layout.frontHousePortal)
            furniture("PortalKitchen", in: layout.kitchenPortal)
            furniture("PrepTable", in: layout.table)
            cuttingBoard
            furniture("TrashCan", in: layout.trashCan)

            ForEach(game.cards.indices, id: \.self) { slot in
                card(in: slot)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: game.cards)
            leftSlice

            if dirtyTraysInBubble > 0 {
                TrayBubble(dirtyTrays: dirtyTraysInBubble, cleanTrays: 0)
                    .placed(in: layout.trayBubble, designSize: trayBubbleSize)
                    .transition(.scale.combined(with: .opacity))
            }
            if let cleanTrayFlight {
                TrayBubble(dirtyTrays: 0, cleanTrays: 1)
                    .placed(in: flightRect(at: cleanTrayFlight), designSize: trayBubbleSize)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: dirtyTraysInBubble)
        .onChange(of: game.traysWashed) { sendCleanTrayToFrontHouse() }
    }

    /// The dirty trays still waiting, less the ones a hand is carrying.
    private var dirtyTraysInBubble: Int { game.crew.dirtyTrays - game.dirtyTraysInHand }

    private var trayBubbleSize: CGSize { CGSize(width: TrayBubble.size, height: TrayBubble.size) }

    private func sendCleanTrayToFrontHouse() {
        cleanTrayFlight = 0
        withAnimation(.easeIn(duration: 1.2).delay(ProcurementGame.finishedBeat)) {
            cleanTrayFlight = 1
        } completion: {
            cleanTrayFlight = nil
        }
    }

    /// The tray bubble's rect slid `progress` of the way to the portal,
    /// shrinking as it goes in.
    private func flightRect(at progress: CGFloat) -> CGRect {
        let from = layout.trayBubble, to = layout.frontHousePortal
        let size = from.width * (1 - 0.7 * progress)
        let center = CGPoint(x: from.midX + (to.midX - from.midX) * progress,
                             y: from.midY + (to.midY - from.midY) * progress)
        return CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
    }

    /// A card's crate always stays in its slot; a card the player left
    /// somewhere is also a bubble there.
    @ViewBuilder private func card(in slot: Int) -> some View {
        let ingredient = game.cards[slot]
        let item = CarriedItem.ingredient(ingredient, cardSlot: slot)
        IngredientCrate(ingredient: ingredient)
            .id(ingredient)
            .transition(.scale.combined(with: .opacity))
            .placed(in: layout.card(slot), designSize: IngredientCrate.size)
        if let spot = game.bubbleSpots[item] {
            IngredientBubble(ingredient: ingredient)
                .opacity(game.itemsInHand.contains(item) ? 0 : 1)
                .placed(in: layout.bubble(at: spot, otherwise: layout.card(slot)), designSize: bubbleSize)
        }
    }

    /// A sliced ingredient taken off the board and left somewhere.
    @ViewBuilder private var leftSlice: some View {
        if let sliced = game.slicedOnBoard, let spot = game.bubbleSpots[.sliced(sliced)] {
            IngredientBubble(ingredient: sliced, isCooked: true)
                .opacity(game.itemsInHand.contains(.sliced(sliced)) ? 0 : 1)
                .placed(in: layout.bubble(at: spot, otherwise: layout.cuttingBoard), designSize: bubbleSize)
        }
    }

    private var bubbleSize: CGSize { CGSize(width: IngredientBubble.size, height: IngredientBubble.size) }

    private var cuttingBoard: some View {
        Image("CuttingBoard")
            .resizable()
            .overlay {
                if let sliced = game.slicedOnBoard, game.bubbleSpots[.sliced(sliced)] == nil {
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
