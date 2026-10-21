//
//  CGRect+Center.swift
//  PlayFeat
//
//  The middle of a rect, for placing things on the layouts' rects.
//

import CoreGraphics

extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
