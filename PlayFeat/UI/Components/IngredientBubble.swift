//
//  IngredientBubble.swift
//  PlayFeat
//
//  One of the Chef's floating bubbles: an ingredient — raw, or the cooked
//  dish — inside the glassy bubble, gently bobbing up and down. The bob is
//  drawing only: the scene hit-tests the bubble's fixed slot, which the bob
//  stays well inside, so floating never gets in the way of a pinch.
//

import SwiftUI

struct IngredientBubble: View {
    let ingredient: KitchenIngredient
    var isCooked = false
    /// Staggers the bob so neighbouring bubbles don't move in step.
    var bobDelay: Double = 0

    static let size: CGFloat = 161.3
    private static let bobHeight: CGFloat = 6

    @State private var isUp = false

    var body: some View {
        ZStack {
            IngredientArt(ingredient: ingredient, size: Self.size * (isCooked ? 0.6 : 0.55), isPrepared: isCooked)
            Image("HeldBubble")
                .resizable()
                .frame(width: Self.size, height: Self.size)
        }
        .frame(width: Self.size, height: Self.size)
        .offset(y: isUp ? -Self.bobHeight : Self.bobHeight)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(bobDelay)) {
                isUp = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Ingredient"))
    }
}

#Preview {
    HStack {
        IngredientBubble(ingredient: .tentacle)
        IngredientBubble(ingredient: .coralLettuce, isCooked: true, bobDelay: 0.4)
    }
    .padding()
    .background(.gray)
}
