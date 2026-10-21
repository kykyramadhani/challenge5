//
//  ChefWorktop.swift
//  PlayFeat
//
//  Everything in the Chef's kitchen over the camera feed (Figma 616:8996 and
//  616:20353): the Procurement portal ingredients arrive through, the Front
//  House portal, the counter with the boiling pot, broth pot and fryer —
//  showing what is cooking or done, and a bar while it boils or fries — the
//  trash can, the five floating raw ingredients, and any finished dish taken
//  out and left elsewhere.
//  Placed from ChefLayout, the same rects the scene hit-tests hands against.
//

import SwiftUI

struct ChefWorktop: View {
    let game: ChefGame
    let layout: ChefLayout

    var body: some View {
        ZStack {
            Image("PortalProcurement")
                .resizable()
                .frame(width: layout.procurementPortal.width, height: layout.procurementPortal.height)
                .position(layout.procurementPortal.center)
            furniture("PortalFrontHouse", in: layout.frontHousePortal, isMirrored: true)
            furniture("PrepTable", in: layout.counter)
            furniture("TrashCan", in: layout.trashCan)

            ForEach(ChefGame.stations, id: \.self) { station in
                CookingStationView(game: game, station: station, layout: layout)
            }
            floatingBubbles
        }
        .accessibilityHidden(true)
    }

    /// Raw ingredients arrive from the Procurement portal.
    private var floatingBubbles: some View {
        FloatingBubbles(bubbles: game.bubbles,
                        slotRect: { slot in
                            let item = game.bubbles[slot].map { CarriedItem.ingredient($0.ingredient, cardSlot: slot) }
                            return layout.bubble(at: item.flatMap { game.bubbleSpots[$0] }, otherwise: layout.bubble(slot))
                        },
                        sourceRect: { _ in layout.procurementPortal },
                        isHeld: { slot, bubble in
                            game.itemsInHand.contains(.ingredient(bubble.ingredient, cardSlot: slot))
                        })
    }

    /// The Front House portal faces the other way on this side of the
    /// kitchen, so its art is mirrored.
    private func furniture(_ image: String, in rect: CGRect, isMirrored: Bool = false) -> some View {
        Image(image)
            .resizable()
            .scaledToFit()
            .scaleEffect(x: isMirrored ? -1 : 1)
            .frame(width: rect.width, height: rect.height)
            .position(rect.center)
    }
}

/// One cooking station: its hob, the pot showing what is in it (simmering
/// while it cooks), the bar under it while it boils or fries, and the
/// finished dish's bubble only once a hand has taken it out and left it.
private struct CookingStationView: View {
    let game: ChefGame
    let station: DropZone
    let layout: ChefLayout

    private var pot: CookingPot { game.pots[station] ?? .empty }

    var body: some View {
        ZStack {
            if let stove = layout.stove(station) {
                art("StoveBurner", in: stove)
            }
            SimmeringPot(image: potImage, isCooking: isCooking)
                .id(isCooking)  // restarts the simmer when cooking begins
                .frame(width: layout.pot(station).width, height: layout.pot(station).height)
                .position(layout.pot(station).center)
            if isCooking { progressBar }
            readyBubble
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: pot)
    }

    private var isCooking: Bool {
        if case .cooking = pot { true } else { false }
    }

    /// The dish has been taken out of the pot: in a hand, or left elsewhere.
    private var isDishOut: Bool {
        guard let dish = pot.readyIngredient else { return false }
        return game.itemsInHand.contains(.cooked(dish)) || game.bubbleSpots[.cooked(dish)] != nil
    }

    /// The pot with what is in it, from the Figma cooking frame.
    private var potImage: String {
        let isFull = !pot.isEmpty && !isDishOut
        switch station {
        case .boilingPot: return isFull ? "BoilPotTuber" : "BoilPot"
        case .brothPot: return isFull ? "BrothPotSoup" : "BrothPot"
        default: return isFull ? "FryerTentacle" : "Fryer"
        }
    }

    /// Read every frame from the shift clock, like the ticket's border.
    private var progressBar: some View {
        TimelineView(.animation) { _ in
            PanelProgressBar(progress: game.cookingProgress(in: station))
        }
        .placed(in: layout.progressBar(station), designSize: PanelProgressBar.size)
        .transition(.opacity)
    }

    @ViewBuilder private var readyBubble: some View {
        if let dish = pot.readyIngredient, let spot = game.bubbleSpots[.cooked(dish)],
           !game.itemsInHand.contains(.cooked(dish)) {
            IngredientBubble(ingredient: dish, isCooked: true)
                .transition(.scale(scale: 0.2).combined(with: .opacity))
                .placed(in: layout.bubble(at: spot, otherwise: layout.pot(station)),
                        designSize: CGSize(width: IngredientBubble.size, height: IngredientBubble.size))
        }
    }

    private func art(_ image: String, in rect: CGRect) -> some View {
        Image(image)
            .resizable()
            .scaledToFit()
            .frame(width: rect.width, height: rect.height)
            .position(rect.center)
    }
}

/// A pot's art, gently swelling while something cooks in it.
private struct SimmeringPot: View {
    let image: String
    let isCooking: Bool

    @State private var isSwollen = false

    var body: some View {
        Image(image)
            .resizable()
            .scaledToFit()
            .scaleEffect(isCooking && isSwollen ? 1.03 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { isSwollen = true }
            }
    }
}
