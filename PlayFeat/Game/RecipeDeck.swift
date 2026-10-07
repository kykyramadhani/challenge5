//
//  RecipeDeck.swift
//  PlayFeat
//
//  Deals a run's recipes, never the same dish twice in a row.
//

import Foundation

struct RecipeDeck {
    private let recipes: [Recipe]

    init(_ recipes: [Recipe]) {
        precondition(!recipes.isEmpty, "RecipeDeck needs at least one recipe")
        self.recipes = recipes
    }

    func randomRecipe() -> Recipe {
        recipes[Int.random(in: recipes.indices)]
    }

    func recipe(after current: Recipe) -> Recipe {
        recipes.filter { $0.name != current.name }.randomElement() ?? current
    }
}
