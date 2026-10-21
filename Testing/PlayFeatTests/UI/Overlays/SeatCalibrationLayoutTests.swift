//
//  SeatCalibrationLayoutTests.swift
//  PlayFeatTests
//  Created by Owen Limantoro on 21/10/26.
//
//  Where the seat check's frame sits: the Figma box, hung off the bottom of
//  every iPad, without changing how close the player has to sit.
//

import Testing
import CoreGraphics
@testable import PlayFeat

@MainActor
struct SeatCalibrationLayoutTests {

    /// On the Figma frame's own size, the box is exactly the design's.
    @Test func onTheFigmaScreenTheBoxMatchesTheDesign() {
        let frame = SeatCalibrationView.targetFrame(in: CGSize(width: 1376, height: 1034))

        #expect(frame == CGRect(x: 138, y: 278, width: 1100, height: 786))
    }

    /// The box always rises from below: its bottom border sits just off the
    /// screen, and it stays centred, on every iPad.
    @Test(arguments: [
        CGSize(width: 1376, height: 1032),  // iPad Pro 13"
        CGSize(width: 1210, height: 834),   // iPad Pro 11"
        CGSize(width: 1180, height: 820),   // iPad Air / iPad
        CGSize(width: 1133, height: 744),   // iPad mini
    ])
    func theBoxHangsOffTheBottomAndStaysCentred(screen: CGSize) {
        let frame = SeatCalibrationView.targetFrame(in: screen)

        #expect(frame.maxY > screen.height)
        #expect(frame.minY > 0)
        #expect(abs(frame.midX - screen.width / 2) < 0.001)
        #expect(frame.width < screen.width)
    }

    /// A bigger box mustn't make players sit closer: the shoulder rule is the
    /// old one, a quarter of a box 54% of the screen wide.
    @Test func theDistanceRuleIsUnchanged() {
        let screen = CGSize(width: 1376, height: 1032)

        let span = SeatCalibrationView.minimumShoulderSpan(in: screen)

        #expect(abs(span - screen.width * 0.54 * 0.25) < 1)
    }
}
