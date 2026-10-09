//
//  GameTestSupport.swift
//  PlayFeatTests
//
//  Created by Owen Limantoro on 06/10/26.
//

import Testing
@testable import PlayFeat

/// A game wired to test doubles: an inventory that lives only in memory, and
/// `GameAudio` playing into a `SoundRecorder` instead of real speakers. Pass your own recorder to check
/// which sounds a rule plays.
///
/// The defaults are `nil` and filled in inside the body on purpose: default
/// values are evaluated outside the main actor, where `Recipe.all` and
/// `SoundRecorder()` (both main-actor isolated) can't be reached.
@MainActor
func makeGame(
    recipes: [Recipe]? = nil,
    startingLives: Int = 3,
    sounds: SoundRecorder? = nil
) -> GameStateManager {
    let game = GameStateManager(
        recipes: recipes ?? Recipe.all,
        startingLives: startingLives,
        inventory: InventoryManager(inMemory: true)
    )
    GameAudio.attach(to: game, sounds: sounds ?? SoundRecorder())
    return game
}
