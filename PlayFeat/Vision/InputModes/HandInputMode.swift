//
//  HandInputMode.swift
//  PlayFeat
//
//  Everything that differs between one-hand and two-hand play, answered by the
//  mode itself so callers don't branch on the setting.
//

import Foundation

protocol HandInputMode {
    /// How many hands the game follows.
    /// `nonisolated` (like `playerWrists`): read on the camera's video queue.
    nonisolated var handCount: Int { get }

    /// The wrists on `body` whose hands belong to the player in this mode.
    /// Empty when none of them was seen this frame.
    nonisolated func playerWrists(of body: HumanBodyPoseManager.BodyCandidate) -> [CGPoint]

    /// What the seat check asks the player to do.
    var calibrationInstruction: String.LocalizationValue { get }
}

extension HandInputMode {
    /// Whether every hand this mode plays with is visible on `body` — the seat
    /// check won't start the game with one of them missing.
    nonisolated func seesEveryHand(on body: HumanBodyPoseManager.BodyCandidate) -> Bool {
        playerWrists(of: body).count == handCount
    }
}
