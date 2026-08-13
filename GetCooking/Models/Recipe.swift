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
    let finishedDishImageName: String
    var ingredientImageNames: [String] { ingredients.map(\.imageName) }
}

extension Recipe {
    static let chickenMayonnaise: Recipe = Recipe(
        name: "Chichken Mayonnaise",
        ingredients: [.chicken, .mayonnaise],
        scoreValue: 15,
        finishedDishImageName: "ChickenMayonnaise"
    )

    static let chickenCheese: Recipe = Recipe(
        name: "Chicken Cheese",
        ingredients: [.chicken, .cheese],
        scoreValue: 15,
        finishedDishImageName: "ChickenMozarella"
    )

    static let salad = Recipe(
        name: "Salad",
        ingredients: [.lettuce, .cucumber, .tomato, .mayonnaise],
        scoreValue: 20,
        finishedDishImageName: "Salad"
    )

    static let chickenGeprek = Recipe(
        name: "Chichken Geprek",
        ingredients: [.chicken, .chili, .cucumber],
        scoreValue: 25,
        finishedDishImageName: "ChickenGeprek"
    )

    static let all: [Recipe] = [.chickenMayonnaise, .salad, .chickenCheese, .chickenGeprek]
}
