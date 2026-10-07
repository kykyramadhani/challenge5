//
//  RecipeDeckTests.swift
//  PlayFeatTests
//
//  How a run deals its recipes.
//

import Testing
@testable import PlayFeat

struct RecipeDeckTests {

    @Test func theNextRecipeIsNeverTheSameDishTwiceInARow() {
        let deck = RecipeDeck(Recipe.all)

        for current in Recipe.all {
            for _ in 0..<20 {
                #expect(deck.recipe(after: current).name != current.name)
            }
        }
    }

    /// With only one recipe there is nothing else to deal.
    @Test func aOneRecipeDeckKeepsDealingIt() {
        let deck = RecipeDeck([.salad])

        #expect(deck.recipe(after: .salad) == .salad)
    }
}
