//
//  ClapDetector.swift
//  GetCooking
//
//  Created by Owen Limantoro on 12/08/26.
//

import SwiftUI

/// Detects both hands being brought together over a target.
///
/// Kept out of `GameScene` so the arming and cooldown rules can be exercised
/// without a live SpriteKit view. All distances are given in *hand spans*
/// rather than points: the same physical clap covers wildly different pixel
/// distances depending on how far the player is sitting from the camera.
struct ClapDetector {
    /// Palms this close together (× span) count as a clap.
    var triggerDistance: CGFloat = 0.9
    
    /// Hands must separate by at least this much (× span) before re-arming.
    var releaseDistance: CGFloat = 1.8
    var cooldown: TimeInterval = 0.8

    private var isArmed = false
    private var lastFired: TimeInterval = -.greatestFiniteMagnitude

    mutating func disarm() { isArmed = false }

    /// True on the frame a clap should fire.
    mutating func update(
        left: CGPoint,
        right: CGPoint,
        span: CGFloat,
        bothHandsEmpty: Bool,
        target: CGPoint,
        targetRadius: CGFloat,
        now: TimeInterval
    ) -> Bool {
        // Two hands each carrying an ingredient into the bowl end up close
        // together over the plate — the clap pose exactly. Requiring both hands
        // to be empty is what stops filling the plate from binning it.
        guard bothHandsEmpty, span > 0 else {
            isArmed = false
            return false
        }

        let separation = hypot(left.x - right.x, left.y - right.y)

        // Hands must part before another clap counts, so resting them together
        // doesn't discard over and over.
        if separation > span * releaseDistance { isArmed = true }

        let midpoint = CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
        guard isArmed,
              separation <= span * triggerDistance,
              hypot(midpoint.x - target.x, midpoint.y - target.y) <= targetRadius,
              now - lastFired > cooldown
        else { return false }

        isArmed = false
        lastFired = now
        return true
    }
}
