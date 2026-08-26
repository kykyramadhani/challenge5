//
//  CoinMultiplierView.swift
//  GetCooking
//
//  Visual component for the coin multiplier item.
//

import SwiftUI

struct coinMultiplier: View {
    var food: String = "Coin"
    let width: CGFloat
    let height: CGFloat
    var dishServed: Int = 2

    var body: some View {
        ZStack {
            Image("Coin")
                .resizable()
                .scaledToFit()
                .frame(width: width, height: height)

            Text("x2")
                .font(.atkinson(size: width * 0.28, weight: .bold))
                .foregroundColor(.appTertiaryText)
                .offset(x: width * 0.5, y: height * 0.28)
        }
    }
}

#Preview {
    coinMultiplier(width: 150, height: 150)
}
