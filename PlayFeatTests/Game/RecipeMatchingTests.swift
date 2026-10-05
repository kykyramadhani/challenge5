//
//  RecipeMatchingTests.swift
//  PlayFeatTests
//
//  Split out of GetCookingTests.swift (created by Kyky on 11/08/26).
//

import Testing
import Foundation
import CoreGraphics
@testable import PlayFeat

struct RecipeMatchingTests {

    @Test func exactMultisetMatches() {
        #expect(GameStateManager.matches(plateContents: [.chicken, .chili, .cucumber], recipe: .chickenGeprek))
    }

    @Test func orderDoesNotMatter() {
        #expect(GameStateManager.matches(plateContents: [.cucumber, .chicken, .chili], recipe: .chickenGeprek))
    }

    @Test func extraIngredientFails() {
        #expect(!GameStateManager.matches(plateContents: [.lettuce, .cucumber, .tomato, .mayonnaise, .cheese], recipe: .salad))
    }

    @Test func missingIngredientFails() {
        #expect(!GameStateManager.matches(plateContents: [.lettuce, .cucumber], recipe: .salad))
    }

    /// Chicken Mayonnaise and Chicken Cheese share a chicken but differ by one item, so a
    /// plate for one must never satisfy the other.
    @Test func similarRecipesDoNotCrossMatch() {
        #expect(!GameStateManager.matches(plateContents: [.chicken, .cheese], recipe: .chickenMayonnaise))
        #expect(!GameStateManager.matches(plateContents: [.chicken, .mayonnaise], recipe: .chickenCheese))
    }

    /// Every recipe's own ingredient list must satisfy it — cheap guard against
    /// a typo when the menu changes.
    @Test func everyRecipeMatchesItself() {
        for recipe in Recipe.all {
            #expect(GameStateManager.matches(plateContents: recipe.ingredients, recipe: recipe))
        }
    }

    /// Each recipe needs at least two decoys available, or the trash bin has
    /// nothing to do that round.
    @Test func everyRecipeLeavesDecoysAvailable() {
        for recipe in Recipe.all {
            let decoys = Ingredient.allCases.filter { !recipe.ingredients.contains($0) }
            #expect(decoys.count >= 2, "\(recipe.name) leaves only \(decoys.count) decoys")
        }
    }
}
