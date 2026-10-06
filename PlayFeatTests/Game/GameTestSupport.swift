//
//  GameTestSupport.swift
//  PlayFeatTests
//
//  Created by Owen Limantoro on 06/10/26.
//

import Testing
@testable import PlayFeat

@MainActor
func makeGame(recipes: [Recipe] = Recipe.all, startingLives: Int = 3) -> GameStateManager {
    GameStateManager(
        recipes: recipes,
        startingLives: startingLives,
        inventory: InventoryManager(inMemory: true)
    )
}
