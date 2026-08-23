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

    /// The coin total, tweened up from zero on appear. Kept as a `Double` so
    /// the count can pass through the in-between values as it animates.
    @State private var animatedTotal: Double = 0

    var body: some View {
        Image("Paycheck")
            .onAppear {
                // Let the paycheck settle in first, then ring up the total.
                withAnimation(.easeOut(duration: 1.0).delay(0.4)) {
                    animatedTotal = Double(total)
                }
            }
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

                            AnimatedCounterText(
                                value: animatedTotal,
                                font: .system(size: h * 0.12, weight: .bold, design: .rounded)
                            )
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

/// A whole number that tweens through the integers between its old and new
/// value whenever that value changes inside `withAnimation` — the coin total
/// ticking up from zero. `Animatable` is what lets SwiftUI drive the in-between
/// frames; a plain `Text("\(Int)")` would just snap to the final number.
private struct AnimatedCounterText: View, Animatable {
    var value: Double
    let font: Font

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int(value.rounded()))")
            .font(font)
            // Keeps the coin total from nudging the layout as the digit count
            // grows from 1 to 2 to 3 places on the way up.
            .monospacedDigit()
    }
}

#Preview {
    PayCheckView(totalDishServed: 20, speedBonus: 100)
}
