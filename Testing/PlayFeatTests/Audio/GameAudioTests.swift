//
//  GameAudioTests.swift
//  PlayFeatTests
//
//  Which sounds each game event plays. Uses SoundRecorder, so nothing plays.
//

import Testing
@testable import PlayFeat

@MainActor
struct GameAudioTests {

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

    /// The order is handed over, the reward chime lands a beat later, and
    /// the music picks up the tempo of the new difficulty tier.
    @Test func servingPlaysTheOrderThenTheReward() async throws {
        let sounds = SoundRecorder()
        let game = makeGame(recipes: [.chickenGeprek], sounds: sounds)
        game.start()
        for ingredient in Recipe.chickenGeprek.ingredients {
            game.addIngredientToPlate(ingredient)
        }
        try await Task.sleep(for: .milliseconds(1200)) // dish reveal beat

        game.serveDish()
        #expect(sounds.played == [.putOrder])
        #expect(sounds.musicRate == game.musicRate)

        try await Task.sleep(for: .milliseconds(500)) // reward chime delay
        #expect(sounds.played == [.putOrder, .addPoint])
    }

    @Test func runningLowStartsAndStopsTheClockWarning() {
        let sounds = SoundRecorder()
        let audio = GameAudio.attach(to: makeGame(), sounds: sounds)

        audio.handle(.lowTimeStarted)
        #expect(sounds.isClockWarningOn)

        audio.handle(.lowTimeEnded)
        #expect(!sounds.isClockWarningOn)
    }

    /// The game tells its listener in the same call, not on the next frame.
    @Test func theGameReportsEachEventAsItHappens() {
        let game = makeGame(recipes: [.salad])
        var heard: [GameEvent] = []
        game.onEvent = { heard.append($0) }
        game.start()
        game.addIngredientToPlate(.tomato)

        game.discardPlate()

        #expect(heard == [.plateDiscarded])
    }

    /// Restarting while the clock wasn't low adds no low-time event.
    @Test func restartingWhenNotLowRecordsOnlyTheRestart() {
        let game = makeGame()
        var heard: [GameEvent] = []
        game.onEvent = { heard.append($0) }
        game.start()

        game.restart()

        #expect(heard == [.runRestarted])
    }
}
