//
//  CGPoint+Distance.swift
//  GetCooking
//

import CoreGraphics

extension CGPoint {
    func vc_distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }

    /// Moves this point `fraction` of the way toward `target`.
    func vc_eased(toward target: CGPoint, by fraction: CGFloat) -> CGPoint {
        CGPoint(
            x: x + (target.x - x) * fraction,
            y: y + (target.y - y) * fraction
        )
    }
}

extension CGFloat {
    func vc_clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
