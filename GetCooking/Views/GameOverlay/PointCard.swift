//
//  PointCard.swift
//  GetCooking
//
//  How many dishes the player has served this run.
//
//  A count of finished plates rather than a points total: the run has no
//  target to hit and every dish is worth the same amount of work, so "3 served"
//  says more about how you're doing than an abstract score does. The plate art
//  is the same dish the player just carried to the tray, so the badge reads
//  without a label.
//

import SwiftUI

struct PointCard: View {
    var dishesServed: Int

    var body: some View {
        HStack(spacing: 20) {
            Image("ServedDish")
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)

            Text("\(dishesServed)")
                .font(.custom(size: 44, weight: .bold))
                .contentTransition(.numericText())
                .animation(.snappy, value: dishesServed)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 14)
        .foregroundStyle(.black)
        .background(
            Capsule()
                .fill(.appPrimary)
        )
    }
}

#Preview {
    PointCard(dishesServed: 3)
}
