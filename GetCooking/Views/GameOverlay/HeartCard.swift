//
//  HeartCard.swift
//  GetCooking
//
//  Created by Owen Limantoro on 13/08/26.
//

import SwiftUI

struct HeartCard: View {
    /// Lives left.
    var hearts: Int

    /// Slots drawn in total. Spent lives stay on as outlines so the capsule
    /// keeps its width instead of the whole HUD shifting on every loss.
    var total: Int = 3

    var body: some View {
        HStack {
            // Half-open range, not `1...hearts`: that traps on an empty
            // range, and the HUD is still on screen at zero lives.
            ForEach(0..<max(total, hearts), id: \.self) { index in
                Image(systemName: index < hearts ? "heart.fill" : "heart")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.appAccent)
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 22)
        .foregroundStyle(.black)
        .background(
            Capsule()
                .fill(.appPrimary)
        )
    }
}

#Preview {
    VStack {
        HeartCard(hearts: 3)
        HeartCard(hearts: 1)
        HeartCard(hearts: 0)
    }
}
