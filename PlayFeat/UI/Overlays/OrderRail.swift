//
//  OrderRail.swift
//  PlayFeat
//
//  Procurement's and the Chef's four order tickets along the top, the
//  active (leftmost) one carrying the clock. When an order leaves, the rest
//  slide left and a new one drops in at the end.
//

import SwiftUI

struct OrderRail<Layout: KitchenLayout>: View {
    let shift: KitchenShift
    let layout: Layout

    var body: some View {
        ForEach(Array(shift.queue.orders.enumerated()), id: \.element.id) { index, order in
            let isActive = index == 0
            OrderTicketView(order: order, isActive: isActive,
                            isRunningLow: isActive && shift.isActiveOrderRunningLow,
                            fractionLeft: { shift.activeFractionLeft })
                .frame(height: OrderTicketView.fullHeight, alignment: .top)
                .placed(in: layout.ticket(index),
                        designSize: CGSize(width: OrderTicketView.width, height: OrderTicketView.fullHeight))
                .transition(.move(edge: .top).combined(with: .opacity))
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: shift.queue.orders.map(\.id))
    }
}
