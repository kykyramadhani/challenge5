//
//  TrayTicketView.swift
//  PlayFeat
//
//  Front House's order ticket (Figma 684:4679): the order drawn as the tray
//  it has to become, with the drink at its corner when one is wanted. The
//  tray and the drink are served separately: a served tray gets a green
//  tick, the glass is faded until it's been poured. Only waiting orders
//  have a ticket, each with its own green clock border, blinking red in its
//  last ten seconds like every role's tickets.
//

import SwiftUI

struct TrayTicketView: View {
    let order: KitchenOrder
    let isRunningLow: Bool
    var fractionLeft: () -> CGFloat = { 1 }

    static let size = CGSize(width: 333, height: 265)
    private let shape = TicketShape(isShort: true)

    var body: some View {
        ZStack(alignment: .topLeading) {
            shape.fill(.white)
            if isRunningLow { RunningLowBlink(shape: shape) }
            ServingTrayView(tray: ServingTray(completing: order), width: 249.7, isDrinkOwed: order.isDrinkOwed)
                .overlay {
                    if order.isTrayServed { DeliveredTick().transition(.scale.combined(with: .opacity)) }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: order.isTrayServed)
                .offset(x: 51.8, y: 16.9)
            TicketClockBorder(ticket: shape, fractionLeft: fractionLeft)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Order"))
    }
}

#Preview {
    TrayTicketView(order: KitchenOrder(id: 0, items: [.starJelly, .coralLettuce, .tentacle], needsDrink: true),
                   isRunningLow: false, fractionLeft: { 0.7 })
        .padding()
        .background(.gray)
}
