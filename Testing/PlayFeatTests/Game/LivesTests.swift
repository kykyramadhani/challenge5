//
//  LivesTests.swift
//  PlayFeatTests
//
//  Split out of GetCookingTests.swift (created by Kyky on 11/08/26).
//

import Testing
import Foundation
import CoreGraphics
@testable import PlayFeat

@MainActor
struct LivesTests {

    /// Running the clock out costs a life but keeps the run going, with the
    /// score intact — the player is being set back, not reset.
    @Test func aTimedOutDishCostsOneLifeAndDealsAnother() {
        let manager = makeGame(recipes: Recipe.all)
        manager.start()
        let recipeBefore = manager.currentRecipe

        manager.failDish()

        #expect(manager.lives == manager.startingLives - 1)
        #expect(manager.totalDishesServed == 0)
        #expect(manager.state == .cooking)
        #expect(manager.currentRecipe != recipeBefore)
        #expect(manager.plateContents.isEmpty)
    }

    /// The scene has no state change to notice here — a dish can time out
    /// while already `.cooking` — so the event is the only signal that the
    /// board must be wiped for the new recipe.
    @Test func aTimedOutDishRecordsALostLife() {
        let manager = makeGame(recipes: Recipe.all)
        manager.start()

        manager.failDish()

        #expect(manager.events.latest?.event == .lifeLost(livesLeft: manager.startingLives - 1))
    }

    /// Losing a life wipes the board but the run carries on, so the player
    /// must not be dropped back into a 3-2-1-GO! countdown. `runNumber` is
    /// what GameplayView keys that countdown off, and only `restart()` moves it.
    @Test func aTimedOutDishKeepsTheSameRun() {
        let manager = makeGame(recipes: Recipe.all)
        manager.start()
        let runBefore = manager.runNumber

        manager.failDish()

        #expect(manager.state == .cooking, "still playing, just a life down")
        #expect(manager.runNumber == runBefore, "no countdown mid-run")
    }

    /// Replay is the other half of that rule: a fresh run *does* get the
    /// countdown back.
    @Test func restartStartsTheNextRun() {
        let manager = makeGame(recipes: Recipe.all)
        manager.start()
        let runBefore = manager.runNumber

        manager.restart()

        #expect(manager.runNumber == runBefore + 1)
    }

    /// The run ends on the last life, and only then — this is the sole way to
    /// reach `.gameOver` now that the round countdown is gone.
    @Test func losingTheLastLifeEndsTheRun() {
        let manager = makeGame(recipes: Recipe.all, startingLives: 2)
        manager.start()

        manager.failDish()
        #expect(manager.state == .cooking, "one life left, still playing")

        manager.failDish()

        #expect(manager.lives == 0)
        #expect(manager.state == .gameOver)
    }

    /// Nothing should keep draining lives after the run is over.
    @Test func failingAfterGameOverChangesNothing() {
        let manager = makeGame(recipes: Recipe.all, startingLives: 1)
        manager.start()
        manager.failDish()
        #expect(manager.state == .gameOver)

        manager.failDish()

        #expect(manager.lives == 0, "lives must not go negative")
    }

    /// The clock covers assembly only. Once the plate matches, the ring goes
    /// away and the dish can no longer time out — otherwise a slow swipe would
    /// cost the life the player just cooked their way out of.
    @Test func theClockStopsOnceTheDishIsAssembled() {
        let manager = makeGame(recipes: [.chickenMayonnaise])
        manager.start()
        #expect(manager.isTimingDish)

        for ingredient in Recipe.chickenMayonnaise.ingredients {
            manager.addIngredientToPlate(ingredient)
        }

        #expect(manager.state == .dishComplete)
        #expect(!manager.isTimingDish, "serving is not timed")
    }

    /// ...and picks up again for the next dish, with that dish's own budget.
    @Test func theClockRestartsForTheNextRecipe() async throws {
        let manager = makeGame(recipes: [.chickenMayonnaise, .salad])
        manager.start()
        for ingredient in manager.currentRecipe.ingredients {
            manager.addIngredientToPlate(ingredient)
        }
        try await Task.sleep(for: .milliseconds(1200))
        #expect(!manager.isTimingDish)

        manager.serveDish()

        #expect(manager.isTimingDish, "the next dish is on the clock")
        #expect(manager.dishTimeLimit == manager.currentRecipe.timeLimit)
        #expect(manager.dishTimeFraction > 0.9, "a fresh dish starts near full")
    }

    /// Serving is scored and does *not* cost a life, so a clean run keeps all
    /// three hearts however long it lasts.
    @Test func servingDoesNotCostALife() async throws {
        let manager = makeGame(recipes: [.chickenMayonnaise, .chickenCheese])
        manager.start()
        for ingredient in manager.currentRecipe.ingredients {
            manager.addIngredientToPlate(ingredient)
        }
        try await Task.sleep(for: .milliseconds(1200))

        manager.serveDish()

        #expect(manager.lives == manager.startingLives)
        #expect(manager.totalDishesServed > 0)
    }

    /// The bell has rung and the serve window is counting down. It is a real
    /// deadline: let it lapse and the order is abandoned, same as a dish that
    /// never got assembled.
    @Test func theServeWindowStartsFullWhenTheBellRings() async throws {
        let manager = makeGame(recipes: [.chickenMayonnaise])
        manager.start()
        for ingredient in manager.currentRecipe.ingredients {
            manager.addIngredientToPlate(ingredient)
        }

        #expect(!manager.isTimingServe, "still showing the finished dish")

        try await Task.sleep(for: .milliseconds(1200))

        #expect(manager.isTimingServe)
        #expect(manager.serveTimeFraction > 0.9,
                "the reveal beat must not eat into the player's window")
    }

    /// The dish clock and the serve clock never run at the same time — each
    /// only applies in its own phase, so a waiting order can't be failed twice.
    @Test func onlyOneClockRunsAtATime() async throws {
        let manager = makeGame(recipes: [.chickenMayonnaise])
        manager.start()

        #expect(manager.isTimingDish)
        #expect(!manager.isTimingServe)

        for ingredient in manager.currentRecipe.ingredients {
            manager.addIngredientToPlate(ingredient)
        }
        try await Task.sleep(for: .milliseconds(1200))

        #expect(!manager.isTimingDish)
        #expect(manager.isTimingServe)
    }

    /// Every five *served* dishes the assembly clock tightens by 1.25×, so the
    /// same recipe has to be built in 80% of the time it had a tier earlier.
    @Test func difficultyRampsEveryFiveServedDishes() async throws {
        let manager = makeGame(recipes: [.chickenMayonnaise, .salad])
        manager.start()

        func serveOneDish() async throws {
            for ingredient in manager.currentRecipe.ingredients {
                manager.addIngredientToPlate(ingredient)
            }
            
            // Long enough for the reveal beat to hand over to the swipe cue.
            try await Task.sleep(for: .milliseconds(1200))
            manager.serveDish()
        }

        // Dishes 1–4 stay on the base budget for whatever recipe is up.
        for _ in 0..<4 { try await serveOneDish() }
        #expect(manager.dishesCompleted == 4)
        #expect(manager.dishTimeLimit == manager.currentRecipe.timeLimit)

        // The 5th serve crosses the first speed-up step, so the dish that
        // starts right after gets 1 / 1.25 of its own recipe's time.
        try await serveOneDish()
        #expect(manager.dishesCompleted == 5)
        #expect(abs(manager.dishTimeLimit - manager.currentRecipe.timeLimit / 1.2) < 0.0001)
    }

    /// A timed-out dish is not "done", so it must not advance the ramp.
    @Test func failedDishesDoNotRampDifficulty() {
        let manager = makeGame(recipes: [.chickenMayonnaise, .salad])
        manager.start()

        manager.failDish()

        #expect(manager.dishesCompleted == 0)
        #expect(manager.dishTimeLimit == manager.currentRecipe.timeLimit)
    }
}
