//
//  OrderTicketView.swift
//  PlayFeat
//
//  One order on the rail, drawn at Figma size (162 pt wide; 295 tall for four
//  items, 147 for two). Each item shows the raw ingredient over how it has to
//  be prepared, ticked off the moment Procurement delivers it. The active
//  ticket carries a green border down its sides and along its bottom that is
//  its clock, and blinks red in its last ten seconds.
//

import SwiftUI

struct OrderTicketView: View {
    let order: KitchenOrder
    let isActive: Bool
    let isRunningLow: Bool
    /// Read every frame while active; the border is the order's clock.
    var fractionLeft: () -> CGFloat = { 1 }

    static let width: CGFloat = 162
    static let fullHeight: CGFloat = 295

    private var isShort: Bool { order.items.count <= 2 }
    private var height: CGFloat { isShort ? TicketShape.tearHeight : Self.fullHeight }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image("OrderTicket")
                .resizable()
                .frame(width: Self.width, height: Self.fullHeight)
                .frame(width: Self.width, height: height, alignment: .top)
                .clipShape(TicketShape(isShort: isShort))

            if isRunningLow { RunningLowBlink(shape: TicketShape(isShort: isShort)) }

            dividers
            ForEach(Array(order.items.enumerated()), id: \.offset) { index, item in
                TicketCell(ingredient: item, isDelivered: order.isDelivered(at: index))
                    .position(Self.cellCenter(index))
            }

            if isActive { TicketClockBorder(ticket: TicketShape(isShort: isShort), fractionLeft: fractionLeft) }
        }
        .frame(width: Self.width, height: height, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Order"))
    }

    private var dividers: some View {
        Path { path in
            path.move(to: CGPoint(x: 81, y: 22))
            path.addLine(to: CGPoint(x: 81, y: 125))
            guard !isShort else { return }
            path.move(to: CGPoint(x: 12.3, y: TicketShape.tearHeight))
            path.addLine(to: CGPoint(x: 148.9, y: TicketShape.tearHeight))
            path.move(to: CGPoint(x: 81, y: 170))
            path.addLine(to: CGPoint(x: 81, y: 273))
        }
        .stroke(.kitchenPurple.opacity(0.6), lineWidth: 1.1)
    }

    /// Two columns, two rows, as laid out in Figma.
    private static func cellCenter(_ index: Int) -> CGPoint {
        CGPoint(x: index.isMultiple(of: 2) ? 39 : 122, y: index < 2 ? 74 : 221)
    }
}

/// An ingredient over its preparation icon; served-as-is items stand alone.
/// Once delivered it fades back under a green tick.
private struct TicketCell: View {
    let ingredient: KitchenIngredient
    let isDelivered: Bool

    var body: some View {
        content
            .opacity(isDelivered ? 0.35 : 1)
            .overlay {
                if isDelivered { DeliveredTick().transition(.scale.combined(with: .opacity)) }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDelivered)
    }

    @ViewBuilder private var content: some View {
        if let icon = ingredient.preparation.iconName {
            VStack(spacing: 5) {
                IngredientArt(ingredient: ingredient, size: 53)
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 63, height: 49)
            }
        } else {
            IngredientArt(ingredient: ingredient, size: 62)
        }
    }
}

/// The green tick over something already delivered or served.
struct DeliveredTick: View {
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 22, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(.ticketTimerGreen, in: Circle())
            .accessibilityLabel(Text("Delivered"))
    }
}

/// The active ticket's clock: a green border down its sides and along its
/// bottom, read every frame, shrinking as the order's time runs out. Shared
/// by every role's tickets.
struct TicketClockBorder: View {
    let ticket: TicketShape
    let fractionLeft: () -> CGFloat

    var body: some View {
        TimelineView(.animation) { _ in
            TicketTimerBorder(ticket: ticket)
                .trim(from: 0, to: fractionLeft())
                .stroke(.ticketTimerGreen, style: StrokeStyle(lineWidth: 5, lineCap: .round))
        }
    }
}

/// The ticket's outline minus its top edge, as a shape the clock can trim.
private struct TicketTimerBorder: Shape {
    let ticket: TicketShape

    func path(in rect: CGRect) -> Path { ticket.sidesAndBottom(in: rect) }
}

/// The white ticket washing red and back, for as long as it is on screen.
struct RunningLowBlink: View {
    let shape: TicketShape
    @State private var isRed = false

    var body: some View {
        shape
            .fill(.red.opacity(isRed ? 0.45 : 0))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) { isRed = true }
            }
    }
}

#Preview {
    HStack(alignment: .top) {
        OrderTicketView(order: KitchenOrder(id: 0, items: [.glowingMushroom, .coralLettuce, .bubbleTuber, .starJelly]),
                        isActive: true, isRunningLow: false, fractionLeft: { 0.7 })
        OrderTicketView(order: KitchenOrder(id: 1, items: [.coralLettuce, .coralLettuce]),
                        isActive: false, isRunningLow: false)
    }
    .padding()
    .background(.gray)
}
