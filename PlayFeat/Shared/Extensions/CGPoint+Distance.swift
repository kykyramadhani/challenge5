//
//  CGPoint+Distance.swift
//  PlayFeat
//
//  The point and number maths every layer shares, from the Vision pipeline
//  to the game scene. `nonisolated` because the Vision types run on the
//  video queue, and these are pure functions with no state to protect.
//

import CoreGraphics

nonisolated extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }

    /// Moves this point `fraction` of the way toward `target`.
    func eased(toward target: CGPoint, by fraction: CGFloat) -> CGPoint {
        CGPoint(
            x: x + (target.x - x) * fraction,
            y: y + (target.y - y) * fraction
        )
    }
}

nonisolated extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
