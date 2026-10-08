//
//  GameState.swift
//  PlayFeat
//
//  The phase a run is in. One-off happenings that don't change the phase are
//  `GameEvent`s instead.
//

import Foundation

enum GameState: Equatable {
    /// Before the game has started (e.g. waiting on camera permission).
    case idle
    /// Ingredients are on the table; the player is assembling the plate.
    case cooking
    /// The plate matched the active recipe; the finished dish is showing.
    case dishComplete
    /// The bell has rung on `bellSide`; waiting for the player to carry the
    /// plate to it. The side travels with the phase, so a bell can't be
    /// waiting without one, or linger once the dish is served.
    case waitingToServe(bellSide: ServeDirection)
    /// The player ran out of lives; play is over until `restart()`.
    case gameOver

    /// Which edge the plate has to be carried to. Nil in every other phase.
    var bellSide: ServeDirection? {
        guard case let .waitingToServe(side) = self else { return nil }
        return side
    }

    var isWaitingToServe: Bool { bellSide != nil }
}
