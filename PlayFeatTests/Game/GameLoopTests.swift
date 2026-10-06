//
//  GameLoopTests.swift
//  PlayFeatTests
//
//  Split out of GetCookingTests.swift (created by Kyky on 11/08/26).
//

import Testing
import Foundation
import CoreGraphics
import SpriteKit
@testable import PlayFeat

@MainActor
struct GameLoopTests {
    /// Swiping down retries the *same* dish — it must not skip to another
    /// recipe or touch the score.
    @Test func discardKeepsTheSameRecipeAndScore() async {
        let manager = makeGame(recipes: [.chickenGeprek])
        manager.start()
        manager.addIngredientToPlate(.cheese) // wrong ingredient
        #expect(manager.plateContents.count == 1)

        manager.discardPlate()
        #expect(manager.plateContents.isEmpty)
        #expect(manager.currentRecipe == .chickenGeprek)
        #expect(manager.totalDishesServed == 0)
    }

    /// A stray downward swipe over an empty plate must not bump the token, or
    /// GameScene would replay the fly-away animation and respawn the table
    /// mid-round.
    @Test func discardingAnEmptyPlateDoesNothing() {
        let manager = makeGame(recipes: [.salad])
        manager.start()
        let tokenBefore = manager.discardToken

        manager.discardPlate()

        #expect(manager.discardToken == tokenBefore)
    }

    @Test func discardBumpsTokenSoTheSceneCanAnimate() {
        let manager = makeGame(recipes: [.salad])
        manager.start()
        manager.addIngredientToPlate(.tomato)
        let discardTokenBefore = manager.discardToken

        manager.discardPlate()

        #expect(manager.discardToken == discardTokenBefore + 1)
    }

    /// The "Play Again does nothing" bug: restarting has to reset the score and
    /// the plate, and bump the token GameScene keys its board wipe off.
    ///
    /// Leaves `state` at `.idle` rather than `.cooking` — a replay has to sit
    /// through the seat check and countdown again, and it's `start()` that
    /// actually resumes play once that beat finishes (see below).
    @Test func restartResetsEverythingAndBumpsResetToken() {
        let manager = makeGame(recipes: [.chickenMayonnaise])
        manager.start()
        manager.addIngredientToPlate(.chicken)
        let resetTokenBefore = manager.resetToken

        manager.restart()

        #expect(manager.plateContents.isEmpty)
        #expect(manager.totalDishesServed == 0)
        #expect(manager.speedBonus == 0)
        #expect(manager.lives == manager.startingLives)
        #expect(manager.elapsedTime == 0)
        #expect(manager.state == .idle)
        #expect(manager.resetToken == resetTokenBefore + 1,
                "GameScene clears the board off this token; without it the old ingredients stay")
    }

    /// `restart()` alone must not resume play — GameplayView's countdown is
    /// what calls `start()` once it finishes, same as the very first run.
    @Test func restartDoesNotResumePlayOnItsOwn() {
        let manager = makeGame(recipes: [.chickenMayonnaise])
        manager.start()
        manager.restart()

        #expect(manager.state == .idle)

        manager.start()
        #expect(manager.state == .cooking)
    }

    @Test func servingCountsTheDishThatWasServed() async throws {
        let manager = makeGame(recipes: [.chickenGeprek])
        manager.start()
        for ingredient in Recipe.chickenGeprek.ingredients {
            manager.addIngredientToPlate(ingredient)
        }
        #expect(manager.state == .dishComplete)

        try await Task.sleep(for: .milliseconds(1200)) // dish reveal beat
        #expect(manager.state == .waitingToServe)

        manager.serveDish()

        #expect(manager.totalDishesServed == 1)
        #expect(manager.dishesByType[Recipe.chickenGeprek.finishedDishImageName] == 1,
                "counted against the dish that was actually served")
    }

    /// Serving is gated on the bell having rung. The plate passes over plenty
    /// of screen while ingredients are still being fetched, and none of that
    /// may count as a delivery.
    @Test func servingBeforeTheBellDoesNothing() {
        let manager = makeGame(recipes: [.chickenMayonnaise])
        manager.start()
        #expect(manager.state == .cooking)

        manager.serveDish()

        #expect(manager.totalDishesServed == 0)
        #expect(manager.state == .cooking, "still cooking")
    }

    /// The bell picks an edge, and that edge is what the scene carries the
    /// plate toward. It has to clear once the dish is gone, or the next round
    /// would start with a stale target.
    @Test func theBellRingsOnOneSideAndClearsAfterServing() async throws {
        let manager = makeGame(recipes: [.chickenMayonnaise, .salad])
        manager.start()
        for ingredient in manager.currentRecipe.ingredients {
            manager.addIngredientToPlate(ingredient)
        }
        try await Task.sleep(for: .milliseconds(1200))

        #expect(manager.state == .waitingToServe)
        let side = try #require(manager.bellSide)
        #expect(side == .left || side == .right)

        manager.serveDish()

        #expect(manager.bellSide == nil)
        #expect(manager.state == .cooking)
    }

    /// A wrong ingredient must not complete the dish.
    @Test func wrongIngredientDoesNotComplete() {
        let manager = makeGame(recipes: [.chickenMayonnaise])
        manager.start()
        manager.addIngredientToPlate(.chicken)
        manager.addIngredientToPlate(.cheese) // should have been mayo
        #expect(manager.state == .cooking)
    }
}
