//
//  CGPoint+Distance.swift
//  GetCooking
//

import CoreGraphics

extension CGPoint {
    func vc_distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}

extension CGFloat {
    func vc_clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
