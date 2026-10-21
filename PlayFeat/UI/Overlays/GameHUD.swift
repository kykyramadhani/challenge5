//
//  GameHUD.swift
//  PlayFeat
//
//  The row across the top of the board during play: dishes served, the
//  current recipe and the hearts left.
//

import SwiftUI

struct GameHUD: View {
    var gameStateManager: GameStateManager

    /// No dish is running during the 3-2-1, so the recipe card stays hidden.
    let isCountingDown: Bool

    var body: some View {
        VStack {
            HStack(alignment: .center) {
                Spacer()

                PointCard(dishesServed: gameStateManager.dishesCompleted)

                Spacer()

                // Hidden rather than removed during the countdown: it still
                // holds its width, so the score and hearts don't jump sideways
                // the moment the first recipe lands.
                RecipeCard(
                    recipe: gameStateManager.currentRecipe,
                    gameStateManager: gameStateManager
                )
                .opacity(isCountingDown ? 0 : 1)

                Spacer()

                HeartCard(
                    hearts: gameStateManager.lives,
                    total: gameStateManager.startingLives
                )

                Spacer()
            }

            Spacer()
        }
        .ignoresSafeArea()
    }
}

#Preview {
    GameHUD(
        gameStateManager: GameStateManager(inventory: InventoryManager(inMemory: true)),
        isCountingDown: false
    )
}
