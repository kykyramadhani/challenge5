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

struct RecipeCardView: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recipe.name)
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())

            HStack(spacing: 14) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, ingredient in
                    VStack(spacing: 3) {
                        Image(uiImage: TrimmedArt.image(named: ingredient.imageName) ?? UIImage())
                            .resizable()
                            .scaledToFit()
                            .frame(width: 46, height: 46)
                            .shadow(color: .black.opacity(0.55), radius: 4, y: 2)

                        Text(ingredient.displayName)
                            .font(.caption2.weight(.medium))
                            .shadow(color: .black.opacity(0.8), radius: 3)
                    }
                }
            }
        }
    }
}

#Preview {
    RecipeCardView(recipe: .salad)
        .padding()
        .background(.gray)
}
