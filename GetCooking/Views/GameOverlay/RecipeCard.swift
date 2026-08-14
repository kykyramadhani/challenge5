//
//  RecipeCardView.swift
//  VisionChef
//
//  The recipe requirements, floating over the camera feed with no backing
//  panel. Only the text carries a tight material capsule; the ingredient art
//  sits directly on the video with a drop shadow for contrast.
//
//  The icons are the *same* assets the bubbles are built from, so what the
//  player is asked for looks exactly like what they have to grab.
//

import SwiftUI

struct RecipeCard: View {
    let recipe: Recipe

    private static let iconSize: CGFloat = 100
    private static let iconSpacing: CGFloat = 24

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
//            Text(recipe.name)
//                .font(.system(size: 32, weight: .bold))
//                .foregroundStyle(.accent)

            // The reserve sets the width; the real icons are centred on top of
            // it. Sizing to the longest possible recipe is what stops the score
            // and heart cards from sliding whenever the dish changes, and
            // overlaying keeps a short recipe centred rather than pushed left.
            widthReserve
                .overlay { ingredientRow }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 20)
        .background(.white)
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: 40,
                bottomTrailingRadius: 40
            )
        )

    }

    /// The dish's actual ingredients.
    private var ingredientRow: some View {
        HStack(spacing: Self.iconSpacing) {
            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, ingredient in
                Image(uiImage: TrimmedArt.image(named: ingredient.imageName) ?? UIImage())
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.iconSize, height: Self.iconSize)
                    .shadow(color: .black.opacity(0.55), radius: 4, y: 2)
            }
        }
    }

    /// Invisible row at the widest a recipe can be, laid out with the same
    /// metrics as the real one so the two can never disagree.
    private var widthReserve: some View {
        HStack(spacing: Self.iconSpacing) {
            ForEach(0..<Recipe.maxIngredientCount, id: \.self) { _ in
                Color.clear
                    .frame(width: Self.iconSize, height: Self.iconSize)
            }
        }
    }
}

#Preview {
    RecipeCard(recipe: .salad)
}
