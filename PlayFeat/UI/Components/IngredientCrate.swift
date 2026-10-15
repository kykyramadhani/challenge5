//
//  IngredientCrate.swift
//  PlayFeat
//
//  One of the three floating ingredient cards: a purple crate with its lid
//  tipped open and the ingredient on a white label. Figma size, 223 × 178.
//

import SwiftUI

struct IngredientCrate: View {
    let ingredient: KitchenIngredient

    static let size = CGSize(width: 223, height: 178)

    var body: some View {
        ZStack(alignment: .topLeading) {
            UnevenRoundedRectangle(topLeadingRadius: 4.25, bottomLeadingRadius: 42.5,
                                   bottomTrailingRadius: 42.5, topTrailingRadius: 4.25)
                .fill(Color.kitchenCrate.shadow(.inner(color: .black.opacity(0.25), radius: 4.25, y: -4.25)))
                .frame(width: 210.6, height: 132.9)
                .offset(x: 6.9, y: 45.1)

            UnevenRoundedRectangle(topLeadingRadius: 21.3, bottomLeadingRadius: 4.25,
                                   bottomTrailingRadius: 4.25, topTrailingRadius: 21.3)
                .fill(Color.kitchenCrateLid.shadow(.inner(color: .black.opacity(0.25), radius: 4.25, y: -2.1)))
                .frame(width: 222.3, height: 34)
                .rotationEffect(.degrees(-1.89))
                .offset(x: 0.5, y: 3.7)

            RoundedRectangle(cornerRadius: 12.8)
                .fill(.white)
                .frame(width: 106.3, height: 88.3)
                .overlay { IngredientArt(ingredient: ingredient, size: 62) }
                .offset(x: 59, y: 67.5)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Ingredient"))
    }
}

#Preview {
    HStack {
        ForEach(KitchenIngredient.allCases, id: \.self) { IngredientCrate(ingredient: $0) }
    }
    .padding()
    .background(.gray)
}
