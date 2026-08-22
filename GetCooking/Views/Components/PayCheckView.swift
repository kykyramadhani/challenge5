//
//  PayCheckView.swift
//  GetCooking
//
//  Created by Owen Limantoro on 22/08/26.
//

import SwiftUI

struct PayCheckView: View {
    let totalDishServed: Int
    let speedBonus: Int

    /// Coins earned per dish served.
    private let dishCost = 10
    private var dishesEarnings: Int { totalDishServed * dishCost }
    private var total: Int { dishesEarnings + speedBonus }

    var body: some View {
        Image("Paycheck")
            .overlay {
                GeometryReader { proxy in
                    let w = proxy.size.width
                    let h = proxy.size.height
                    let sidePadding = w * 0.09

                    VStack(spacing: 0) {
                        // Header band — the title.
                        Text("Nice work today!")
                            .font(.system(size: h * 0.15, weight: .bold, design: .rounded))
                            .foregroundStyle(.appTertiaryText)
                            .minimumScaleFactor(0.5)
                            .frame(width: w, height: h * 0.42)

                        // Middle band — the itemised lines.
                        VStack(spacing: h * 0.04) {
                            lineRow(
                                label: "\(totalDishServed)x Dishes Served",
                                value: dishesEarnings,
                                height: h
                            )
                            lineRow(
                                label: "Speed Bonus",
                                value: speedBonus,
                                height: h
                            )
                        }
                        .padding(.horizontal, sidePadding)
                        .frame(width: w, height: h * 0.37)

                        // Footer band — the total, with a coin.
                        HStack(spacing: w * 0.02) {
                            Text("TOTAL")
                                .font(.system(size: h * 0.1, weight: .bold, design: .rounded))

                            Spacer()
                            
                            Image("Coin")
                                .resizable()
                                .frame(width: h * 0.12, height: h * 0.12)
                                .scaledToFit()

                            Text("\(total)")
                                .font(.system(size: h * 0.12, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.appBackground)
                        .padding(.horizontal, sidePadding)
                        .frame(width: w, height: h * 0.21)
                    }
                }
            }
    }

    /// One "label ............ value" line in the middle band.
    private func lineRow(label: String, value: Int, height: CGFloat) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)")
        }
        .font(.system(size: height * 0.08, weight: .bold, design: .rounded))
        .foregroundStyle(.appBackground)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

#Preview {
    PayCheckView(totalDishServed: 20, speedBonus: 100)
}
