//
//  GetCookingGameState.swift
//  GetCooking
//
//  Created by Owen Limantoro on 15/08/26.
//

import SwiftUI

enum GameState: Equatable {
    /// Before the game has started (e.g. waiting on camera permission).
    case idle
    /// Ingredients are on the table; the player is assembling the plate.
    case cooking
    /// The plate matched the active recipe; the finished dish is showing.
    case dishComplete
    /// The bell has rung; waiting for the player to carry the plate to it.
    case waitingToServe
    /// The player ran out of lives; play is over until `restart()`.
    case gameOver
}
