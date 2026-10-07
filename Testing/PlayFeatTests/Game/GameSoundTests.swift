//
//  GameSoundTests.swift
//  PlayFeatTests
//
//  Which sounds the game rules ask for. Uses SoundRecorder, so nothing plays.
//

import Testing
@testable import PlayFeat

@MainActor
struct GameSoundTests {

    @Test func losingALifePlaysTheLoseHeartSting() {
        let sounds = SoundRecorder()
        let game = makeGame(sounds: sounds)
        game.start()

        game.failDish()

        #expect(sounds.played == [.loseHeart])
    }

    /// The dish that ran out was the one ticking, so its warning stops.
    @Test func losingALifeSilencesTheClockWarning() {
        let sounds = SoundRecorder()
        let game = makeGame(sounds: sounds)
        game.start()
        sounds.startClockWarning()

        game.failDish()

        #expect(!sounds.isClockWarningOn)
    }

    /// A new run must not carry the last run's warning loop or fast tempo
    /// into its countdown.
    @Test func restartingResetsTheMusicAndWarning() {
        let sounds = SoundRecorder()
        let game = makeGame(sounds: sounds)
        game.start()
        sounds.startClockWarning()
        sounds.setMusicRate(1.6)

        game.restart()

        #expect(sounds.played.last == .reset)
        #expect(sounds.musicRate == 1.0)
        #expect(!sounds.isClockWarningOn)
    }

    @Test func dumpingThePlatePlaysTheResetSound() {
        let sounds = SoundRecorder()
        let game = makeGame(recipes: [.salad], sounds: sounds)
        game.start()
        game.addIngredientToPlate(.tomato)

        game.discardPlate()

        #expect(sounds.played.last == .reset)
    }

    /// Nothing to dump, nothing happens — not even a sound.
    @Test func dumpingAnEmptyPlateIsSilent() {
        let sounds = SoundRecorder()
        let game = makeGame(recipes: [.salad], sounds: sounds)
        game.start()

        game.discardPlate()

        #expect(sounds.played.isEmpty)
    }
}
