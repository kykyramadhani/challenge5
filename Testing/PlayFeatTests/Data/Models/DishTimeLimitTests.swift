//
//  DishTimeLimitTests.swift
//  PlayFeatTests
//
//  Split out of GetCookingTests.swift (created by Kyky on 11/08/26).
//

import Testing
import Foundation
import CoreGraphics
@testable import PlayFeat

struct DishTimeLimitTests {

    /// Each dish carries its own assembly budget, so pin the shipped numbers.
    ///
    /// They all sit at 30s today, and the difficulty ramp squeezes that as the
    /// run goes on rather than the recipes differing from each other. The
    /// field is still per-recipe, so a fiddly dish can be given more room
    /// without touching the others.
    @Test func everyRecipeDeclaresItsOwnLimit() {
        #expect(Recipe.chickenMayonnaise.timeLimit == 13)
        #expect(Recipe.chickenCheese.timeLimit == 13)
        #expect(Recipe.chickenGeprek.timeLimit == 18)
        #expect(Recipe.salad.timeLimit == 23)
    }

    /// Every recipe must be worth some time, or it would fail the instant it
    /// was dealt.
    @Test func everyRecipeGetsTimeOnTheClock() {
        for recipe in Recipe.all {
            #expect(recipe.timeLimit > 0, "\(recipe.name) has no time limit")
        }
    }
}
