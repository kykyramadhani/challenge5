//
//  GameEvent.swift
//  PlayFeat
//
//  Something that happened during a run, which the scene, HUD and GameAudio
//  react to once — the phase alone can't show it (a timed-out dish stays
//  `.cooking`).
//

import Foundation

enum GameEvent: Equatable {
    /// A brand-new run: the board is wiped and the countdown plays again.
    case runRestarted
    /// A dish timed out. The hearts flash; while lives are left, the board is
    /// wiped for the next recipe without a countdown — the run carries on.
    case lifeLost(livesLeft: Int)
    /// The player emptied the plate; its contents float back to the table.
    case plateDiscarded
    /// The plate reached the bell. Recorded after the difficulty has stepped
    /// up, so anything read from the game now describes the next dish.
    case dishServed
    /// The dish clock dropped into its last stretch.
    case lowTimeStarted
    /// The dish clock is no longer running low: the dish was finished, ran
    /// out, or the game was paused.
    case lowTimeEnded

    /// Whether the scene has to clear the table and lay the round out again.
    /// Not on the last life: the run is over, and the board stays as it was
    /// under the game-over cover.
    var wipesBoard: Bool {
        switch self {
        case .runRestarted: true
        case .lifeLost(let livesLeft): livesLeft > 0
        case .plateDiscarded, .dishServed, .lowTimeStarted, .lowTimeEnded: false
        }
    }
}
