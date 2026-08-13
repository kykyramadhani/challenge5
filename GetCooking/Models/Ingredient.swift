//
//  Ingredient.swift
//  VisionChef
//

import Foundation

enum Ingredient: String, CaseIterable, Codable {
    case cheese
    case chicken
    case chili
    case cucumber
    case lettuce
    case mayonnaise
    case tomato
    
    var displayName: String {
        switch self {
        case .cheese:
            "Cheese"
        case .lettuce:
            "Lettuce"
        case .tomato:
            "Tomato"
        case .chili:
            "Chili"
        case .chicken:
            "Chicken"
        case .mayonnaise:
            "Mayonnaise"
        case .cucumber:
            "Cucumber"
        }
    }
    
    var imageName: String {
        rawValue
    }
}
