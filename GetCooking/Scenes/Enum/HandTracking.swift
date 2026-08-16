//
//  HandTracking.swift
//  GetCooking
//
//  Created by Owen Limantoro on 13/08/26.
//

import Foundation

enum HandState { case unknown, open, fist }

struct HandTracker {
    var previousState: HandState = .unknown
    var held: IngredientNode?
    var lastSeen: TimeInterval = 0

    /// When this hand first read as open while carrying something, or nil if
    /// it currently reads as a fist.
    ///
    /// Releasing waits on this. `HandData.isClosedFist` is exactly
    /// `!isOpenHand`, so every frame is one or the other with nothing in
    /// between — a fist caught at a bad angle, or blurred mid-drag, reads as
    /// open for a frame and would otherwise drop what the player is holding.
    var openSince: TimeInterval?
}
