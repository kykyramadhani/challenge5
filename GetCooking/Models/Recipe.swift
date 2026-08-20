//
//  Recipe.swift
//  VisionChef
//

import Foundation

struct Recipe: Identifiable, Equatable, Hashable {
    var id: String { name }
    let name: String
    let ingredients: [Ingredient]
    let scoreValue: Int

    /// Seconds the player gets to **assemble** this dish before it costs a
    /// life. Serving it afterwards is not timed.
    ///
    /// Set per recipe rather than derived from the ingredient count, so a dish
    /// that is fiddly for reasons other than its length can be given room
    /// without disturbing the others.
    let timeLimit: TimeInterval

    let finishedDishImageName: String

    var ingredientImageNames: [String] { ingredients.map(\.imageName) }
}

extension Recipe {
    static let chickenMayonnaise: Recipe = Recipe(
        name: "Chichken Mayonnaise",
        ingredients: [.chicken, .mayonnaise],
        scoreValue: 15,
        timeLimit: 30,
        finishedDishImageName: "ChickenMayonnaise"
    )

    static let chickenCheese: Recipe = Recipe(
        name: "Chicken Cheese",
        ingredients: [.chicken, .cheese],
        scoreValue: 15,
        timeLimit: 30,
        finishedDishImageName: "ChickenMozarella"
    )

    static let salad = Recipe(
        name: "Salad",
        ingredients: [.lettuce, .cucumber, .tomato, .mayonnaise],
        scoreValue: 20,
        timeLimit: 30,
        finishedDishImageName: "salad"
    )

    static let chickenGeprek = Recipe(
        name: "Chichken Geprek",
        ingredients: [.chicken, .chili, .cucumber],
        scoreValue: 25,
        timeLimit: 30,
        finishedDishImageName: "ChickenGeprek"
    )

    static let all: [Recipe] = [.chickenMayonnaise, .salad, .chickenCheese, .chickenGeprek]

    /// The most ingredients any recipe calls for.
    ///
    /// `RecipeCard` reserves room for this many so its width never changes
    /// between dishes — otherwise the score and heart cards either side of it
    /// shift across the screen every time the recipe does. Derived rather than
    /// written as `4`, so adding a longer recipe widens the card on its own.
    static let maxIngredientCount = all.map(\.ingredients.count).max() ?? 0
}
