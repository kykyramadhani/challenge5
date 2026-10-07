//
//  GameTestSupport.swift
//  PlayFeatTests
//
//  Created by Owen Limantoro on 06/10/26.
//

import Testing
@testable import PlayFeat

/// Built once for the whole test target: AudioManager configures the audio
/// session and preloads every clip, which is too slow to repeat per test.
/// Muted, so `play`, music and the clock warning all stay silent.
@MainActor private let silentAudio: AudioManager = {
    let audio = AudioManager()
    audio.isEnabled = false
    return audio
}()

@MainActor
func makeGame(recipes: [Recipe] = Recipe.all, startingLives: Int = 3) -> GameStateManager {
    GameStateManager(
        recipes: recipes,
        startingLives: startingLives,
        inventory: InventoryManager(inMemory: true),
        audio: silentAudio
    )
}
