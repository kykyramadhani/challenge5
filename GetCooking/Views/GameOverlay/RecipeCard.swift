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

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
//            Text(recipe.name)
//                .font(.system(size: 32, weight: .bold))
//                .foregroundStyle(.accent)

            HStack(spacing: 24) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) {
                    _,
                    ingredient in
                    VStack(spacing: 3) {
                        Image(
                            uiImage: TrimmedArt.image(
                                named: ingredient.imageName
                            ) ?? UIImage()
                        )
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .shadow(color: .black.opacity(0.55), radius: 4, y: 2)
                    }
                }
            }
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
}

#Preview {
    RecipeCard(recipe: .salad)
}
