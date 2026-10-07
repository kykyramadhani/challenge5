//
//  OneHandMode.swift
//  PlayFeat
//
//  For players with one arm available: only the chosen hand is tracked and has
//  to be raised; the other is ignored like a bystander's.
//

import Foundation

struct OneHandMode: HandInputMode {
    /// The hand the player chose in Settings.
    let hand: HandSide

    let handCount = 1

    func playerWrists(of body: HumanBodyPoseManager.BodyCandidate) -> [CGPoint] {
        body.wrist(on: hand).map { [$0] } ?? []
    }

    /// Two full sentences rather than one with the hand name filled in:
    /// Indonesian doesn't put "left"/"right" where English does.
    var calibrationInstruction: String.LocalizationValue {
        switch hand {
        case .left: "Adjust your seat and raise your left hand"
        case .right: "Adjust your seat and raise your right hand"
        }
    }
}
