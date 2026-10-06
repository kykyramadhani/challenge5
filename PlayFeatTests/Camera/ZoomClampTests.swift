//
//  ZoomClampTests.swift
//  PlayFeatTests
//
//  Split out of GetCookingTests.swift (created by Kyky on 11/08/26).
//

import Testing
import Foundation
import CoreGraphics
@testable import PlayFeat

struct ZoomClampTests {

    /// The framing presets are multiples of the *hardware floor*, not literal
    /// zoom factors — 1.0 has to land on the floor wherever that sits, or the
    /// "widest" preset silently crops in on devices whose floor is below 1.
    @Test func wideMultipleLandsOnTheHardwareFloor() {
        #expect(CameraManager.zoomFactor(multiple: 1.0, widest: 0.5, maximum: 8) == 0.5)
        #expect(CameraManager.zoomFactor(multiple: 1.0, widest: 1.0, maximum: 8) == 1.0)
    }

    /// The 1× preset is exactly twice the widest view — the same 2× crop
    /// Apple's Camera app uses to get 1× out of an ultra-wide front sensor.
    @Test func normalMultipleDoublesTheFloor() {
        #expect(CameraManager.zoomFactor(multiple: 2.0, widest: 0.5, maximum: 8) == 1.0)
    }

    /// Setting `videoZoomFactor` outside the format's range raises, so both
    /// ends are clamped rather than trusted.
    @Test func clampsToBothEnds() {
        #expect(CameraManager.zoomFactor(multiple: 0.1, widest: 1.0, maximum: 8) == 1.0)
        #expect(CameraManager.zoomFactor(multiple: 100, widest: 1.0, maximum: 8) == 8)
    }
}
