//
//  HandPoseMappingTests.swift
//  PlayFeatTests
//
//  Split out of GetCookingTests.swift (created by Kyky on 11/08/26).
//

import Testing
import Foundation
import CoreGraphics
@testable import PlayFeat

struct HandPoseMappingTests {

    /// Portrait VGA feed, as delivered after the capture connection rotates it.
    private let buffer = CGSize(width: 480, height: 640)

    /// Vision's origin is bottom-left; view space is top-left. Getting this
    /// backwards is what made grabbing require reaching for the vertical
    /// mirror image of the ingredient, so pin the axis direction.
    @Test func normalizedTopOfFrameMapsToTopOfView() {
        let view = CGSize(width: 960, height: 1280) // exactly 3:4, no cropping

        let mapped = HandPoseManager.viewPoint(
            fromNormalized: CGPoint(x: 0.5, y: 0.9), viewSize: view, bufferSize: buffer
        )

        #expect(abs(mapped.y - 128) < 0.001) // (1 - 0.9) * 1280
        #expect(mapped.y < view.height / 2)
    }

    /// The centre of the frame stays the centre of the screen no matter how
    /// much aspect-fill crops — a cheap invariant that catches sign errors.
    @Test func frameCentreMapsToViewCentreOnEveryAspect() {
        for view in [CGSize(width: 393, height: 852),   // iPhone
                     CGSize(width: 834, height: 1194),  // iPad Pro 11"
                     CGSize(width: 1024, height: 1366)] // iPad Pro 13"
        {
            let mapped = HandPoseManager.viewPoint(
                fromNormalized: CGPoint(x: 0.5, y: 0.5), viewSize: view, bufferSize: buffer
            )
            #expect(abs(mapped.x - view.width / 2) < 0.001)
            #expect(abs(mapped.y - view.height / 2) < 0.001)
        }
    }

    /// `.resizeAspectFill` scales the feed to cover the view and crops the
    /// overflow. On a 19.5:9 iPhone that hides ~123pt of frame on each side —
    /// stretching instead of cropping is what pulled the skeleton off the hand.
    @Test func aspectFillCropPushesFrameEdgesOffScreen() {
        let iPhone = CGSize(width: 393, height: 852)

        let leftEdge = HandPoseManager.viewPoint(
            fromNormalized: CGPoint(x: 0, y: 0.5), viewSize: iPhone, bufferSize: buffer
        )
        let rightEdge = HandPoseManager.viewPoint(
            fromNormalized: CGPoint(x: 1, y: 0.5), viewSize: iPhone, bufferSize: buffer
        )

        #expect(leftEdge.x < 0)                 // cropped off the left
        #expect(rightEdge.x > iPhone.width)     // cropped off the right
        #expect(abs(leftEdge.x + 123) < 1.0)    // ~123pt hidden per side
        // Symmetric about the centre.
        #expect(abs((leftEdge.x + rightEdge.x) / 2 - iPhone.width / 2) < 0.001)
    }

    /// A 4:3 screen matches the feed exactly, so nothing is cropped — this is
    /// why the old stretched mapping looked correct on an iPad Pro 13".
    @Test func matchingAspectCropsNothing() {
        let squareIsh = CGSize(width: 1024, height: 1366) // 3:4 within rounding

        let leftEdge = HandPoseManager.viewPoint(
            fromNormalized: CGPoint(x: 0, y: 0.5), viewSize: squareIsh, bufferSize: buffer
        )

        #expect(abs(leftEdge.x) < 1.0)
    }

    /// Before the first frame arrives there is no buffer size to work from;
    /// fall back to a plain stretch rather than dividing by zero.
    @Test func missingBufferSizeFallsBackToStretch() {
        let view = CGSize(width: 400, height: 800)

        let mapped = HandPoseManager.viewPoint(
            fromNormalized: CGPoint(x: 0.25, y: 0.75), viewSize: view, bufferSize: .zero
        )

        #expect(abs(mapped.x - 100) < 0.001)
        #expect(abs(mapped.y - 200) < 0.001)
    }
}
