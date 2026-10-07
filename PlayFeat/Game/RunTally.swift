//
//  RunTally.swift
//  PlayFeat
//
//  What the run has earned so far — what the paycheck at the end reports.
//

import Foundation

struct RunTally {
    /// Served dishes of each kind, keyed by the recipe's
    /// `finishedDishImageName` (e.g. "salad", "ChickenGeprek").
    private(set) var dishesByType: [String: Int] = [:]

    /// Whole seconds of dish clock left over across the run — the paycheck's
    /// "Speed Bonus". A dish finished with 3 seconds to spare adds 3.
    private(set) var speedBonus = 0

    var totalDishesServed: Int { dishesByType.values.reduce(0, +) }

    mutating func recordCompletedDish(_ recipe: Recipe, secondsLeft: Int) {
        dishesByType[recipe.finishedDishImageName, default: 0] += 1
        speedBonus += secondsLeft
    }
}
