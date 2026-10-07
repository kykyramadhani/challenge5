//
//  GameEvent.swift
//  PlayFeat
//
//  Something that happened during a run, which the scene and HUD react to once —
//  the phase alone can't show it (a timed-out dish stays `.cooking`).
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

    /// Whether the scene has to clear the table and lay the round out again.
    /// Not on the last life: the run is over, and the board stays as it was
    /// under the game-over cover.
    var wipesBoard: Bool {
        switch self {
        case .runRestarted: true
        case .lifeLost(let livesLeft): livesLeft > 0
        case .plateDiscarded: false
        }
    }
}
