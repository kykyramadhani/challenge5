//
//  TrayTimerGeometryTests.swift
//  PlayFeatTests
//
//  Split out of GetCookingTests.swift (created by Kyky on 11/08/26).
//

import Testing
import Foundation
import CoreGraphics
import SpriteKit
@testable import PlayFeat

/// The tray's serve dial: a white face that fills red as the window runs out.
struct TrayTimerGeometryTests {

    private let radius: CGFloat = 50

    /// Tolerance in points. The arc is drawn as Béziers, so the bounds land a
    /// hair off the ideal circle.
    private let slack: CGFloat = 0.5

    /// A fully spent window covers the whole face.
    @Test func aSpentWindowCoversTheWholeDisc() {
        let box = TrayTimerNode.wedgePath(radius: radius, fraction: 1).boundingBoxOfPath

        #expect(abs(box.width - radius * 2) < slack)
        #expect(abs(box.height - radius * 2) < slack)
    }

    /// Spent time sweeps clockwise from 12 o'clock, so half a window is the
    /// *right* half of the disc. This pins both the start angle and the sweep
    /// direction — mirror either one and this fails.
    @Test func halfAWindowIsTheRightHalf() {
        let box = TrayTimerNode.wedgePath(radius: radius, fraction: 0.5).boundingBoxOfPath

        #expect(abs(box.maxX - radius) < slack, "reaches the right edge")
        #expect(abs(box.minX) < slack, "stops at the centre line")
        #expect(abs(box.height - radius * 2) < slack, "spans the full height")
    }

    /// A full window draws no red at all, leaving the white face and its ring.
    @Test func aFullWindowDrawsNothing() {
        let box = TrayTimerNode.wedgePath(radius: radius, fraction: 0).boundingBoxOfPath

        #expect(box.width < slack)
    }

    /// `update(fraction:)` takes time *remaining*, so a full dial must draw an
    /// empty wedge — inverting this would show a spent timer the instant the
    /// bell rang.
    @Test func theDialTakesTimeRemainingNotTimeSpent() {
        let barelyStarted = TrayTimerNode.wedgePath(radius: radius, fraction: 1 - 0.95)
        let nearlyOver = TrayTimerNode.wedgePath(radius: radius, fraction: 1 - 0.05)

        #expect(barelyStarted.boundingBoxOfPath.width < nearlyOver.boundingBoxOfPath.width)
    }
}
