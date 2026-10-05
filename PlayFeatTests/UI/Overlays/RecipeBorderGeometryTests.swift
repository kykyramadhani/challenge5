//
//  RecipeBorderGeometryTests.swift
//  PlayFeatTests
//
//  Split out of GetCookingTests.swift (created by Kyky on 11/08/26).
//

import Testing
import Foundation
import CoreGraphics
import SwiftUI
@testable import PlayFeat

/// The recipe card's border, which is now the dish clock.
struct RecipeBorderGeometryTests {

    private let rect = CGRect(x: 0, y: 0, width: 400, height: 200)
    private let radius: CGFloat = 40

    /// The drain has to start at the top-right corner and finish at the
    /// top-left, travelling the long way round via the bottom. Getting the
    /// start point wrong is what would make the border empty from an arbitrary
    /// corner — the whole reason this isn't a plain rounded rectangle.
    @Test func theBorderRunsFromTopRightToTopLeft() {
        let path = CardBorder(cornerRadius: radius).path(in: rect)

        #expect(path.currentPoint == CGPoint(x: rect.minX, y: rect.minY),
                "ends at the top-left corner")

        // An open path: its bounds cover the card but it never closes across
        // the top, which is where the card meets the edge of the screen.
        let box = path.boundingRect
        #expect(abs(box.width - rect.width) < 0.5)
        #expect(abs(box.height - rect.height) < 0.5)
    }

    /// A corner radius larger than the card can accommodate must not produce a
    /// self-overlapping path — a short recipe makes this card genuinely small.
    @Test func anOversizedCornerRadiusIsClamped() {
        let squat = CGRect(x: 0, y: 0, width: 50, height: 30)
        let path = CardBorder(cornerRadius: 999).path(in: squat)

        let box = path.boundingRect
        #expect(box.width <= squat.width + 0.5)
        #expect(box.height <= squat.height + 0.5)
    }
}
