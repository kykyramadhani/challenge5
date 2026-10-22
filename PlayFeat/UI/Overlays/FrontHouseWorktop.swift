//
//  FrontHouseWorktop.swift
//  PlayFeat
//
//  Everything at Front House over the camera feed (Figma 702:188, 684:4679,
//  684:7562, 702:5268, 702:15350): the green bar table — with the active
//  order's tray on it while the customer eats, then its dirty tray — the
//  Chef portal on the left, the Procurement portal on the right, the clean
//  tray stand with its count, the dispenser and a filled glass, the five
//  floating dishes, and the tray being assembled. Placed from
//  FrontHouseLayout, the same rects the scene hit-tests hands against.
//

import SwiftUI

struct FrontHouseWorktop: View {
    let game: FrontHouseGame
    let layout: FrontHouseLayout

    var body: some View {
        ZStack {
            BarTable()
                .frame(width: layout.barTable.width, height: layout.barTable.height)
                .position(layout.barTable.center)
            tableTop
            art("PortalKitchen", in: layout.chefPortal)
            art("PortalProcurement", in: layout.procurementPortal, isMirrored: true)
            TrayStand(cleanTrays: game.crew.cleanTrays, layout: layout)
            art("Dispenser", in: layout.dispenser)
            drinkBubble
            assemblyTray
            FloatingBubbles(bubbles: game.bubbles, isCooked: true,
                            slotRect: { slot in
                                let item = game.bubbles[slot].map { CarriedItem.dish($0.ingredient, slot: slot) }
                                return layout.bubble(at: item.flatMap { game.bubbleSpots[$0] },
                                                     otherwise: layout.bubble(slot))
                            },
                            sourceRect: { $0.preparation.isChefWork ? layout.chefPortal : layout.procurementPortal },
                            isHeld: { slot, bubble in game.itemsInHand.contains(.dish(bubble.ingredient, slot: slot)) })
        }
        .accessibilityHidden(true)
    }

    // MARK: - The table

    /// Each served order where its ticket was: its tray while the customer
    /// eats, then the dirty tray waiting to go back to Procurement.
    private var tableTop: some View {
        let shown = Array(game.queue.orders.prefix(FrontHouseLayout.ticketCount).enumerated())
        return ForEach(shown, id: \.element.id) { index, order in
            switch order.stage {
            case .waiting:
                EmptyView()
            case .eating:
                ServingTrayView(tray: ServingTray(completing: order), width: layout.eatingTray(index).width)
                    .position(layout.eatingTray(index).center)
                    .transition(.scale.combined(with: .opacity))
            case .finishedEating:
                TrayBubble(dirtyTrays: 1, cleanTrays: 0)
                    .opacity(isHeld(.dirtyTray) && index == firstDirtyIndex ? 0 : 1)
                    .placed(in: layout.dirtyTrayBubble(index),
                            designSize: CGSize(width: TrayBubble.size, height: TrayBubble.size))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: game.queue.orders.map(\.stage))
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: game.queue.orders.map(\.id))
    }

    /// The dirty tray a hand takes first.
    private var firstDirtyIndex: Int? {
        game.queue.orders.firstIndex { $0.stage == .finishedEating }
    }

    // MARK: - The counter

    @ViewBuilder private var assemblyTray: some View {
        let rect = layout.assemblyTray
        if let tray = game.tray {
            ServingTrayView(tray: tray, width: rect.width)
                .opacity(isHeld(.servingTray(tray)) ? 0 : 1)
                .position(rect.center)
                .transition(.scale.combined(with: .opacity))
        } else {
            // Where the next clean tray goes.
            TrayArtView(isDirty: false, size: rect.size)
                .opacity(0.25)
                .position(rect.center)
        }
    }

    @ViewBuilder private var drinkBubble: some View {
        if game.isDrinkReady {
            IngredientBubble(imageName: TrayArt.drinkImage, artScale: 0.45)
                .opacity(isHeld(.drink) ? 0 : 1)
                .placed(in: layout.bubble(at: game.bubbleSpots[.drink], otherwise: layout.drinkBubble),
                        designSize: CGSize(width: IngredientBubble.size, height: IngredientBubble.size))
                .transition(.scale(scale: 0.2).combined(with: .opacity))
        }
    }

    private func isHeld(_ item: CarriedItem) -> Bool {
        game.itemsInHand.contains(item)
    }

    /// The Procurement portal faces the other way on this side, so its art
    /// is mirrored.
    private func art(_ image: String, in rect: CGRect, isMirrored: Bool = false) -> some View {
        Image(image)
            .resizable()
            .scaledToFit()
            .scaleEffect(x: isMirrored ? -1 : 1)
            .frame(width: rect.width, height: rect.height)
            .position(rect.center)
    }
}

/// The long green bar table the served trays stand on.
private struct BarTable: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(LinearGradient(colors: [.barTableTop, .barTableBottom], startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.barTableEdge, lineWidth: 4.8))
    }
}

/// The purple stand on the left where clean trays from Procurement wait,
/// with how many there are. A tray coming back flies in from the
/// Procurement portal; the count itself is always the shared inventory's.
private struct TrayStand: View {
    let cleanTrays: Int
    let layout: FrontHouseLayout

    /// 0 at the Procurement portal, 1 at the stand, while a tray flies in.
    @State private var flight: CGFloat?

    private static let traySize = CGSize(width: 180.6, height: 146.8)

    var body: some View {
        let stand = layout.trayStand
        ZStack {
            RoundedRectangle(cornerRadius: 31.35)
                .fill(LinearGradient(colors: [.trayStandPurple.opacity(0.8), .trayStandPurple.opacity(0.5)],
                                     startPoint: .leading, endPoint: .trailing))
                .overlay(RoundedRectangle(cornerRadius: 31.35).stroke(.trayStandPurple, lineWidth: 11))
                .shadow(color: .trayStandPurple, radius: 14)
                .frame(width: stand.width, height: stand.height)
                .position(stand.center)
            if cleanTrays > 0 {
                tray.position(stand.center)
            }
            if let flight {
                tray.position(point(at: flight))
            }
            badge
        }
        .onChange(of: cleanTrays) { old, new in
            guard new > old else { return }
            flight = 0
            withAnimation(.easeInOut(duration: 0.9)) { flight = 1 } completion: { flight = nil }
        }
    }

    private var tray: some View {
        TrayArtView(isDirty: false, size: CGSize(width: Self.traySize.width * layout.scale,
                                                 height: Self.traySize.height * layout.scale))
    }

    private var badge: some View {
        Text("x\(cleanTrays)")
            .font(.atkinson(size: 36, weight: .bold))
            .foregroundStyle(.kitchenInk)
            .frame(width: 64, height: 64)
            .background(.white, in: Circle())
            .placed(in: layout.trayCountBadge, designSize: CGSize(width: 64, height: 64))
            .contentTransition(.numericText())
            .animation(.snappy, value: cleanTrays)
    }

    private func point(at progress: CGFloat) -> CGPoint {
        let from = layout.procurementPortal.center, to = layout.trayStand.center
        return CGPoint(x: from.x + (to.x - from.x) * progress, y: from.y + (to.y - from.y) * progress)
    }
}

/// Front House's three tray tickets. A served order's ticket gives way to its
/// tray on the table and the next ticket becomes active in place; the rail
/// only slides left once the dirty tray is back.
struct FrontHouseRail: View {
    let shift: KitchenShift
    let layout: FrontHouseLayout

    var body: some View {
        let shown = Array(shift.queue.orders.prefix(FrontHouseLayout.ticketCount).enumerated())
        ForEach(shown, id: \.element.id) { index, order in
            if order.stage == .waiting {
                TrayTicketView(order: order,
                               isRunningLow: shift.runningLowOrderIDs.contains(order.id),
                               fractionLeft: { shift.fractionLeft(of: order) })
                    .placed(in: layout.trayTicket(index), designSize: TrayTicketView.size)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: shift.queue.orders.map(\.id))
    }
}
