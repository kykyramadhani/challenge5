//
//  TwoHandMode.swift
//  PlayFeat
//
//  The default mode: the player cooks with both hands, and both must be up for
//  the seat check.
//

import Foundation

struct TwoHandMode: HandInputMode {
    let handCount = 2

    func playerWrists(of body: HumanBodyPoseManager.BodyCandidate) -> [CGPoint] {
        body.wrists
    }

    var calibrationInstruction: String.LocalizationValue {
        "Adjust your seat to fit in the frame"
    }
}
