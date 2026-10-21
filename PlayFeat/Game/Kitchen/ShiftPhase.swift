//
//  ShiftPhase.swift
//  PlayFeat
//  Created by Owen Limantoro on 21/10/26.
//
//  The order every kitchen shift opens in: the seat check picks and locks
//  the player, the 3-2-1 lets them settle, then the shift plays. Kept out of
//  the view so the order can be tested.
//

nonisolated enum ShiftPhase: Equatable {
    /// The player sits in the frame with their hands up, so the hand
    /// pipeline knows who to follow for the rest of the shift.
    case seatCheck
    /// The 3-2-1. The shift's clocks haven't started.
    case countdown
    case playing

    /// Where a shift starts. Without a seat check (the simulator, where a
    /// finger stands in for a hand, or the DEBUG shortcut into play) it goes
    /// straight to the countdown.
    static func opening(withSeatCheck: Bool) -> ShiftPhase {
        withSeatCheck ? .seatCheck : .countdown
    }

    /// The phase that follows once this one is done.
    var next: ShiftPhase {
        switch self {
        case .seatCheck: .countdown
        case .countdown, .playing: .playing
        }
    }
}
