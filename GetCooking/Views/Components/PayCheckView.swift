//
//  PayCheckView.swift
//  GetCooking
//
//  Created by Owen Limantoro on 22/08/26.
//

import SwiftUI

struct PayCheckView: View {
//    let totalDishServed: Int
//    let speedBonus: Int
//    let dishesEarning: Int
//    let totalCoins: Int
    
    let result: GameResult

    /// The coin total, tweened up from zero on appear. Kept as a `Double` so
    /// the count can pass through the in-between values as it animates.
    @State private var animatedTotal: Double = 0

    var body: some View {
        Image("Paycheck")
            .onAppear {
                // Let the paycheck settle in first, then ring up the total.
                withAnimation(.easeOut(duration: 1.0).delay(0.4)) {
                    animatedTotal = Double(result.totalCoins)
                }
            }
            .overlay {
                GeometryReader { proxy in
                    let w = proxy.size.width
                    let h = proxy.size.height
                    let sidePadding = w * 0.09

                    VStack(spacing: 0) {
                        // Header band — the title.
                        Text(result.newHighScore ? "New Personal Best!" : "Nice work today!")
                            .font(.custom(size: h * 0.15, weight: .bold))
                            .foregroundStyle(.appTertiaryText)
                            .minimumScaleFactor(0.5)
                            .frame(width: w, height: h * 0.42)

                        // Middle band — the itemised lines.
                        VStack(spacing: result.hasMultiplier ? h * 0.02 : h * 0.04) {
                            lineRow(
                                count: result.totalDishesServed,
                                label: "Dishes Served",
                                value: result.dishesEarnings,
                                height: h
                            )
                            
                            lineRow(
                                label: "Speed Bonus",
                                value: result.speedBonus,
                                height: h
                            )
                            
                            if result.hasMultiplier {
                                lineRow(
                                    label: "Coin Multiplier x2",
                                    value: result.baseCoins,
                                    height: h
                                )
                            }
                        }
                        .padding(.horizontal, sidePadding)
                        .frame(width: w, height: h * 0.37)

                        // Footer band — the total, with a coin.
                        HStack(spacing: w * 0.02) {
                            Text("TOTAL")
                                .font(.custom(size: h * 0.1, weight: .bold))

                            Spacer()
                            
                            Image("Coin")
                                .resizable()
                                .frame(width: h * 0.12, height: h * 0.12)
                                .scaledToFit()

                            AnimatedCounterText(
                                value: animatedTotal,
                                font: .custom(size: h * 0.12, weight: .bold)
                            )
                        }
                        .foregroundStyle(.appBackground)
                        .padding(.horizontal, sidePadding)
                        .frame(width: w, height: h * 0.21)
                    }
                }
            }
    }

    /// One "count label ............ value" line in the middle band.
    ///
    /// `count` and `value` are drawn with `Text(verbatim:)`, not plain
    /// interpolation into a `LocalizedStringKey`: digits read the same in
    /// every language this app ships, and keeping the noun (`label`) as its
    /// own standalone catalog key — rather than baked into a key alongside
    /// the count — means it does not depend on guessing the exact
    /// placeholder syntax Xcode's string extractor would have produced.
    private func lineRow(count: Int? = nil, label: LocalizedStringKey, value: Int, height: CGFloat) -> some View {
        HStack {
            HStack(spacing: 4) {
                if let count {
                    Text(verbatim: "\(count)x")
                }
                
                Text(label)
            }
            
            Spacer()
            
            Text(verbatim: "\(value)")
        }
        .font(.custom(size: height * 0.08, weight: .bold))
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
    PayCheckView(result: .init(dishesByType: ["salad" : 1], speedBonus: 100))
}
