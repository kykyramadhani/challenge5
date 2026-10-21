//
//  IngredientArt.swift
//  PlayFeat
//
//  An ingredient's Figma art, raw or prepared, fitted to a square slot.
//

import SwiftUI

struct IngredientArt: View {
    let ingredient: KitchenIngredient
    let size: CGFloat
    var isPrepared = false

    var body: some View {
        Image(isPrepared ? ingredient.preparedImageName : ingredient.rawImageName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
