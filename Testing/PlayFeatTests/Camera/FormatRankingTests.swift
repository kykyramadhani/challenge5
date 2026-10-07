//
//  FormatRankingTests.swift
//  PlayFeatTests
//
//  Split out of GetCookingTests.swift (created by Kyky on 11/08/26).
//

import Testing
import Foundation
import CoreGraphics
@testable import PlayFeat

struct FormatRankingTests {
    /// Every resolution of one sensor reports the same field of view, so this
    /// last term is what actually chooses the format. Ranking it lowest-first
    /// is what fed a 640×480 image to a full-screen Retina preview.
    @Test func higherResolutionWinsAtEqualFieldOfView() {
        let low = CameraManager.ranking(horizontalFieldOfView: 54, width: 640, height: 480)
        let high = CameraManager.ranking(horizontalFieldOfView: 54, width: 1920, height: 1440)

        #expect(high > low)
    }

    /// A 4:3 format sees more vertically than a 16:9 one at the same
    /// horizontal angle, and the game is played in portrait — so height beats
    /// raw pixel count even though the 16:9 format is nominally larger.
    @Test func tallerFrameOutranksResolution() {
        let fourThree = CameraManager.ranking(horizontalFieldOfView: 54, width: 640, height: 480)
        let sixteenNine = CameraManager.ranking(horizontalFieldOfView: 54, width: 1920, height: 1080)

        #expect(fourThree > sixteenNine)
    }

    /// Horizontal angle dominates both other terms: seeing the player's hands
    /// at all matters more than seeing them sharply.
    @Test func widerLensOutranksEverythingElse() {
        let narrowButSharp = CameraManager.ranking(horizontalFieldOfView: 54, width: 1920, height: 1440)
        let wideButSoft = CameraManager.ranking(horizontalFieldOfView: 106, width: 640, height: 480)

        #expect(wideButSoft > narrowButSharp)
    }

    /// A format that reports nothing usable must not outrank a real one.
    @Test func unusableFormatRanksLast() {
        let broken = CameraManager.ranking(horizontalFieldOfView: 0, width: 0, height: 0)
        let real = CameraManager.ranking(horizontalFieldOfView: 54, width: 640, height: 480)

        #expect(real > broken)
    }
}
