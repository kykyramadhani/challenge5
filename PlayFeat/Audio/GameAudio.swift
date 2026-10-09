//
//  GameAudio.swift
//  PlayFeat
//
//  Turns what happens in a run into sound. GameStateManager only records
//  events; this listens to them and decides what the player hears, so the
//  game rules never touch audio and the sound design lives in one place.
//

import Foundation

final class GameAudio {

    /// The reward chime lands this long after the order is handed over.
    static let rewardChimeDelay: TimeInterval = 0.35

    private let sounds: any SoundPlaying

    /// Weak: the game owns this listener, not the other way round.
    private weak var game: GameStateManager?

    private init(game: GameStateManager, sounds: any SoundPlaying) {
        self.game = game
        self.sounds = sounds
    }

    /// Starts playing `game`'s sounds through `sounds`. The game keeps the
    /// listener alive for as long as it lives, so the result can be ignored.
    @discardableResult
    static func attach(to game: GameStateManager, sounds: any SoundPlaying) -> GameAudio {
        let audio = GameAudio(game: game, sounds: sounds)
        game.onEvent = { event in audio.handle(event) }
        return audio
    }

    /// Internal rather than private so tests can feed events straight in.
    func handle(_ event: GameEvent) {
        switch event {
        case .runRestarted:
            // A new run must not carry the last run's warning loop or fast
            // tempo into its countdown.
            sounds.stopClockWarning()
            syncMusicRate()
            sounds.play(.reset)

        case .lifeLost:
            // The dish ran out from under the player; the warning stops and
            // the lost-life sting plays instead.
            sounds.stopClockWarning()
            sounds.play(.loseHeart)

        case .plateDiscarded:
            // The on-screen Reset button fires this, so it gets the reset sound.
            sounds.play(.reset)

        case .dishServed:
            sounds.play(.putOrder)
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.rewardChimeDelay) { [sounds] in
                sounds.play(.addPoint)
            }
            // The music speeds up in lock-step with the tier that just
            // squeezed the clock, so the run audibly gets harder.
            syncMusicRate()

        case .lowTimeStarted:
            sounds.startClockWarning()

        case .lowTimeEnded:
            sounds.stopClockWarning()
        }
    }

    private func syncMusicRate() {
        guard let game else { return }
        sounds.setMusicRate(game.musicRate)
    }
}
