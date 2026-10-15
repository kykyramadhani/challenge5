//
//  IngredientBubble.swift
//  PlayFeat
//
//  A floating bubble (Chef, Front House): an ingredient — raw, or the cooked
//  dish — inside the glassy bubble, gently bobbing up and down. The bob is
//  drawing only: the scene hit-tests the bubble's fixed slot, which the bob
//  stays well inside, so floating never gets in the way of a pinch.
//

import SwiftUI

struct IngredientBubble: View {
    private let imageName: String
    /// The art's size as a fraction of the bubble.
    private let artScale: CGFloat
    /// Staggers the bob so neighbouring bubbles don't move in step.
    private let bobDelay: Double

    init(ingredient: KitchenIngredient, isCooked: Bool = false, bobDelay: Double = 0) {
        self.init(imageName: isCooked ? ingredient.preparedImageName : ingredient.rawImageName,
                  artScale: isCooked ? 0.6 : 0.55, bobDelay: bobDelay)
    }

    /// Anything else that floats: Front House's filled glass.
    init(imageName: String, artScale: CGFloat, bobDelay: Double = 0) {
        self.imageName = imageName
        self.artScale = artScale
        self.bobDelay = bobDelay
    }

    static let size: CGFloat = 161.3
    private static let bobHeight: CGFloat = 6

    @State private var isUp = false

    var body: some View {
        ZStack {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: Self.size * artScale, height: Self.size * artScale)
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
