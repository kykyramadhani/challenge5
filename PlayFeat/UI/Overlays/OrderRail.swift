//
//  OrderRail.swift
//  PlayFeat
//
//  Procurement's and the Chef's order tickets along the top, each carrying
//  its own clock. When an order leaves, the rest slide left; new ones drop
//  in at the end as they arrive.
//

import SwiftUI

struct OrderRail<Layout: KitchenLayout>: View {
    let shift: KitchenShift
    let layout: Layout

    var body: some View {
        ForEach(Array(shift.queue.orders.enumerated()), id: \.element.id) { index, order in
            OrderTicketView(order: order, isOnClock: order.stage == .waiting,
                            isRunningLow: shift.runningLowOrderIDs.contains(order.id),
                            fractionLeft: { shift.fractionLeft(of: order) })
                .frame(height: OrderTicketView.fullHeight, alignment: .top)
                .placed(in: layout.ticket(index),
                        designSize: CGSize(width: OrderTicketView.width, height: OrderTicketView.fullHeight))
                .transition(.move(edge: .top).combined(with: .opacity))
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: shift.queue.orders.map(\.id))
    }
}
