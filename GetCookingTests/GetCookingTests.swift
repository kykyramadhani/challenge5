//
//  GetCookingTests.swift
//  GetCookingTests
//
//  Created by Kyky on 11/08/26.
//

import Testing
import CoreGraphics
import SpriteKit
import SwiftUI
import UIKit
@testable import GetCooking

@MainActor
struct ArtAssetTests {

    /// Every ingredient plus the bubble and plate must resolve to a real image.
    /// This is the test that fires when art is renamed or dropped into the
    /// wrong catalog — otherwise the only symptom is an empty bubble on screen.
    @Test func everyReferencedAssetExists() {
        for ingredient in Ingredient.allCases {
            #expect(TrimmedArt.image(named: ingredient.imageName) != nil,
                    "missing art '\(ingredient.imageName)' for \(ingredient.displayName)")
        }

        // Catalog lookups are case-sensitive even though the filesystem the
        // assets are authored on is not, which is how `salad` shipped as
        // "Salad" and left the finished dish invisible.
        for recipe in Recipe.all {
            #expect(TrimmedArt.image(named: recipe.finishedDishImageName) != nil,
                    "missing finished-dish art '\(recipe.finishedDishImageName)' for \(recipe.name)")
        }

        #expect(TrimmedArt.image(named: GameArt.bubble) != nil)
        #expect(TrimmedArt.image(named: GameArt.plate) != nil)
    }

    /// The serving station's two pieces. `BellNode` builds them by name, and a
    /// missing one leaves the player carrying the plate at empty space with no
    /// other symptom.
    @Test func theServingStationArtExists() {
        #expect(UIImage(named: "Tray") != nil)
        #expect(UIImage(named: "RingingBell") != nil)
    }

    /// The served-dish count's icon. Referenced by name from `PointCard`, so a
    /// rename leaves the badge showing a bare number with no other symptom.
    @Test func theServedDishIconExists() {
        #expect(UIImage(named: "ServedDish") != nil)
    }

    /// The source art sits on 1920×1080 canvases with the subject filling as
    /// little as 28% of the width. If trimming regresses, every bubble silently
    /// renders a fraction of its intended size.
    @Test func trimmingRemovesCanvasPadding() {
        for ingredient in Ingredient.allCases {
            guard let image = TrimmedArt.image(named: ingredient.imageName) else { continue }
            #expect(image.size.width < 1900,
                    "\(ingredient.imageName) still \(image.size.width)pt wide — padding not trimmed")
        }
    }

    /// The bubble is drawn round, so its trimmed art must be close to square —
    /// a lopsided result means the crop picked up stray pixels.
    @Test func trimmedBubbleIsSquare() throws {
        let bubble = try #require(TrimmedArt.image(named: GameArt.bubble))
        let ratio = bubble.size.width / bubble.size.height
        #expect(abs(ratio - 1) < 0.1, "bubble aspect \(ratio) is not square")
    }

    /// Repeated lookups must hand back the identical cached instance; the trim
    /// scans pixels and would otherwise rerun for every bubble spawned.
    @Test func repeatedLookupsAreCached() throws {
        let first = try #require(TrimmedArt.image(named: GameArt.bubble))
        let second = try #require(TrimmedArt.image(named: GameArt.bubble))
        #expect(first === second)
    }
}

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

/// The evidence-counter pinch state machine. This is the thing that stops one
/// bad frame from dropping what the player is holding.
struct PinchDetectorTests {

    private let close: CGFloat = 0.3
    private let open: CGFloat = 0.5

    /// Feeds the same reading in `times` times.
    private func feed(
        _ detector: inout PinchDetector,
        ratio: CGFloat?,
        times: Int
    ) {
        for _ in 0..<times {
            detector.record(ratio: ratio, closeRatio: close, openRatio: open)
        }
    }

    /// One pinched frame is not enough — it takes a run of them.
    @Test func aSingleFrameDoesNotCommitAPinch() {
        var detector = PinchDetector(framesToCommit: 3)

        feed(&detector, ratio: 0.1, times: 1)
        #expect(!detector.isPinching)

        feed(&detector, ratio: 0.1, times: 2)
        #expect(detector.isPinching, "three agreeing frames commit it")
    }

    /// The bug this whole thing exists for: a hand mid-grab that throws one
    /// spurious "apart" frame must keep holding on.
    @Test func oneStrayApartFrameDoesNotRelease() {
        var detector = PinchDetector(framesToCommit: 3)
        feed(&detector, ratio: 0.1, times: 3)
        #expect(detector.isPinching)

        feed(&detector, ratio: 0.9, times: 1)

        #expect(detector.isPinching, "one bad frame must not let go")
    }

    /// A sustained release still works — this is not a one-way latch.
    @Test func aSustainedApartRunReleases() {
        var detector = PinchDetector(framesToCommit: 3)
        feed(&detector, ratio: 0.1, times: 3)

        feed(&detector, ratio: 0.9, times: 3)

        #expect(!detector.isPinching)
    }

    /// Evidence has to be *consecutive*: alternating frames never commit,
    /// because each one resets the other side's counter.
    @Test func alternatingFramesNeverCommit() {
        var detector = PinchDetector(framesToCommit: 3)

        for _ in 0..<10 {
            detector.record(ratio: 0.1, closeRatio: close, openRatio: open)
            detector.record(ratio: 0.9, closeRatio: close, openRatio: open)
        }

        #expect(!detector.isPinching, "never three in a row either way")
    }

    /// An unmeasurable frame is not evidence of being apart. A thumb that
    /// blinks out of tracking used to read as letting go.
    @Test func aMissingReadingHoldsTheCurrentState() {
        var detector = PinchDetector(framesToCommit: 3)
        feed(&detector, ratio: 0.1, times: 3)
        #expect(detector.isPinching)

        feed(&detector, ratio: nil, times: 10)

        #expect(detector.isPinching, "no reading is not a release")
    }

    /// Readings between the thresholds are ambiguous and count for neither
    /// side, so a hand hovering at the boundary holds rather than chattering.
    @Test func readingsInsideTheHysteresisBandHoldTheState() {
        var detector = PinchDetector(framesToCommit: 3)
        feed(&detector, ratio: 0.1, times: 3)

        feed(&detector, ratio: 0.4, times: 10)

        #expect(detector.isPinching)
    }

    /// Clearing evidence keeps the committed state — a hand coasting through a
    /// dropped frame resumes as what it was, not as a half-built opposite.
    @Test func clearingEvidenceKeepsTheCommittedState() {
        var detector = PinchDetector(framesToCommit: 3)
        feed(&detector, ratio: 0.1, times: 3)

        // Two frames of contrary evidence, then a dropout wipes them.
        feed(&detector, ratio: 0.9, times: 2)
        detector.clearEvidence()
        feed(&detector, ratio: 0.9, times: 2)

        #expect(detector.isPinching, "the earlier partial run must not carry over")
    }
}

/// Grabbing is a thumb-to-index-finger pinch. The shipped thresholds are
/// 0.3 (grab) and 0.5 (open), with hysteresis in between.
struct PinchClassifierTests {

    private let palmLength: CGFloat = 1.0

    /// The shipped values, so these tests fail if the thresholds drift apart
    /// from the fixtures below rather than silently going vacuous.
    private let closeRatio: CGFloat = 0.3
    private let openRatio: CGFloat = 0.5

    /// Tips touching. They never reach 0 — the joints sit inside the fingers —
    /// so this has to clear the grab threshold with room, not just beat zero.
    @Test func tipsTogetherReadAsAPinch() {
        let ratio = HandPoseManager.pinchRatio(
            thumbTip: CGPoint(x: 0, y: 0),
            indexTip: CGPoint(x: 0.15, y: 0),
            palmLength: palmLength
        )

        #expect(ratio == 0.15)
        #expect(ratio! <= closeRatio, "clears the shipped grab threshold")
    }

    /// A spread open hand puts the two tips a full palm-width apart or more —
    /// comfortably past the open threshold, never mistakeable for a grab.
    @Test func aSpreadHandIsWellClearOfTheGrabThreshold() {
        let ratio = HandPoseManager.pinchRatio(
            thumbTip: CGPoint(x: 0, y: 0),
            indexTip: CGPoint(x: 1.1, y: 0),
            palmLength: palmLength
        )

        #expect(ratio! >= openRatio, "reads as open, not held by hysteresis")
    }

    /// The whole point of the change: a clenched fist is no longer a grab.
    ///
    /// This is the close call for a thumb-to-*index* pinch specifically — a
    /// fist folds the thumb across the curled index, so these two tips end up
    /// nearer each other than any other pair on the hand. ~0.6 palm lengths
    /// still has to land on the open side of the threshold.
    @Test func aClenchedFistIsNotAGrab() {
        let ratio = HandPoseManager.pinchRatio(
            thumbTip: CGPoint(x: 0, y: 0),
            indexTip: CGPoint(x: 0.6, y: 0),
            palmLength: palmLength
        )

        #expect(ratio! >= openRatio, "a fist must read as open")
    }

    /// Scale-free: the same pinch twice as far from the camera must classify
    /// identically, since the gap is divided by palm length.
    @Test func pinchIsIndependentOfDistanceFromCamera() {
        let near = HandPoseManager.pinchRatio(
            thumbTip: CGPoint(x: 0, y: 0),
            indexTip: CGPoint(x: 0.3, y: 0),
            palmLength: palmLength
        )
        let far = HandPoseManager.pinchRatio(
            thumbTip: CGPoint(x: 0, y: 0),
            indexTip: CGPoint(x: 0.15, y: 0),
            palmLength: palmLength / 2
        )

        #expect(near == far)
    }

    /// A tip that dropped out of tracking is not a grab — the caller opens the
    /// hand rather than clamping shut on whatever is nearby.
    @Test func aMissingTipHasNoPinchMeasurement() {
        #expect(HandPoseManager.pinchRatio(
            thumbTip: nil, indexTip: CGPoint(x: 0.2, y: 0), palmLength: palmLength
        ) == nil)

        #expect(HandPoseManager.pinchRatio(
            thumbTip: CGPoint(x: 0, y: 0), indexTip: nil, palmLength: palmLength
        ) == nil)
    }

    @Test func anUnmeasurablePalmHasNoPinchMeasurement() {
        #expect(HandPoseManager.pinchRatio(
            thumbTip: CGPoint(x: 0, y: 0),
            indexTip: CGPoint(x: 0.2, y: 0),
            palmLength: 0
        ) == nil)
    }
}

struct HoverDetectorTests {

    /// The shipped `maxFrameGap` deliberately caps how much a single frame can
    /// contribute; these tests jump the clock in one step, so they lift it.
    private func detector(dwell: TimeInterval = 2.0) -> HoverDetector {
        var detector = HoverDetector()
        detector.dwellDuration = dwell
        detector.maxFrameGap = 60
        return detector
    }

    // `update` is mutating and `#expect` expands its argument into a closure
    // that captures immutably, so every call is hoisted into a `let` first.

    /// The whole gesture: hold still over the bin and it fires once the full
    /// dwell has elapsed, and not a frame before.
    @Test func holdingTheDwellFires() {
        var detector = detector()

        let atStart = detector.update(isHovering: true, now: 0)
        let midway = detector.update(isHovering: true, now: 1.0)
        let atDwell = detector.update(isHovering: true, now: 2.0)

        #expect(!atStart)
        #expect(!midway)
        #expect(atDwell)
    }

    /// Moving off the bin part-way through starts the next attempt from zero,
    /// so a hand brushing past twice can never add up to a discard.
    @Test func movingAwayResetsTheDwell() {
        var detector = detector()
        _ = detector.update(isHovering: true, now: 0)
        _ = detector.update(isHovering: true, now: 1.9)
        _ = detector.update(isHovering: false, now: 2.0)   // hand leaves

        // Steps land on halves so the accumulated total is exact — summing
        // tenths drifts just under the dwell and the last frame never fires.
        let restarted = detector.update(isHovering: true, now: 3.0)
        let partway = detector.update(isHovering: true, now: 4.5)
        let completed = detector.update(isHovering: true, now: 5.0)

        #expect(!restarted)
        #expect(!partway, "only 1.5s into the fresh dwell")
        #expect(completed)
    }

    /// A hand left resting on the bin discards once, not on every frame for as
    /// long as it sits there.
    @Test func firesOnceWhileTheHandStaysPut() {
        var detector = detector()
        _ = detector.update(isHovering: true, now: 0)

        let first = detector.update(isHovering: true, now: 2.0)
        let second = detector.update(isHovering: true, now: 4.0)
        let third = detector.update(isHovering: true, now: 10.0)

        #expect(first)
        #expect(!second, "a parked hand must not discard over and over")
        #expect(!third)
    }

    /// Leaving and coming back is a deliberate second discard.
    @Test func leavingRearmsForASecondDiscard() {
        var detector = detector()
        _ = detector.update(isHovering: true, now: 0)
        let first = detector.update(isHovering: true, now: 2.0)

        _ = detector.update(isHovering: false, now: 2.5)    // hand leaves
        _ = detector.update(isHovering: true, now: 3.0)
        let second = detector.update(isHovering: true, now: 5.0)

        #expect(first)
        #expect(second)
    }

    /// Pausing stops SpriteKit calling `update(_:)` at all, so `now` jumps
    /// seconds ahead on resume. A hand resting over the bin across a pause must
    /// not have its dwell completed for it. Uses the shipped cap, not the test one.
    @Test func aPausedSceneDoesNotCompleteTheDwell() {
        var detector = HoverDetector()
        _ = detector.update(isHovering: true, now: 0)

        let afterPause = detector.update(isHovering: true, now: 30)

        #expect(!afterPause)
    }

    /// `progress` drives the ring around the bin, so it has to track the dwell
    /// and clear the moment the hand leaves.
    @Test func progressTracksTheDwellAndClearsOnLeaving() {
        var detector = detector()
        _ = detector.update(isHovering: true, now: 0)
        _ = detector.update(isHovering: true, now: 1.0)
        #expect(abs(detector.progress - 0.5) < 0.001)

        _ = detector.update(isHovering: false, now: 1.1)
        #expect(detector.progress == 0)
    }
}

/// Easing a carried ingredient toward the hand.
struct DragEasingTests {

    private let sixtyHz: TimeInterval = 1.0 / 60
    private let oneTwentyHz: TimeInterval = 1.0 / 120

    /// The base is defined as "one 60Hz frame", so at 60Hz it passes straight
    /// through — otherwise the number in `dragSmoothing` would mean nothing.
    @Test func aSixtyHertzFrameUsesTheBaseUnchanged() {
        let eased = GameScene.easing(base: 0.5, delta: sixtyHz)

        #expect(abs(eased - 0.5) < 0.0001)
    }

    /// The whole point: a ProMotion iPad draws twice as often, so each frame
    /// must move the bubble less or the drag ends up twice as twitchy on the
    /// device this is tuned on.
    @Test func aShorterFrameEasesLess() {
        let eased = GameScene.easing(base: 0.5, delta: oneTwentyHz)

        #expect(eased < 0.5)
        // Two 120Hz frames have to land where one 60Hz frame does.
        let afterTwo = 1 - (1 - eased) * (1 - eased)
        #expect(abs(afterTwo - 0.5) < 0.0001)
    }

    @Test func aLongerFrameEasesMore() {
        #expect(GameScene.easing(base: 0.5, delta: 2 / 60.0) > 0.5)
    }

    /// After a stall, closing the whole gap at once would snap a carried
    /// bubble across the screen.
    @Test func aStalledFrameIsCapped() {
        let stalled = GameScene.easing(base: 0.5, delta: 5)
        let capped = GameScene.easing(base: 0.5, delta: GameScene.maxEasingDelta)

        #expect(stalled == capped)
        #expect(stalled < 1)
    }

    /// The first frame has no previous timestamp to measure against.
    @Test func noPreviousFrameFallsBackToTheBase() {
        #expect(GameScene.easing(base: 0.5, delta: 0) == 0.5)
    }

    @Test func degenerateBasesAreHandled() {
        #expect(GameScene.easing(base: 0, delta: sixtyHz) == 0, "frozen")
        #expect(GameScene.easing(base: 1, delta: sixtyHz) == 1, "snaps")
    }

    /// Easing must actually close the gap, and never overshoot it.
    @Test func easingMovesTowardTheTargetWithoutOvershooting() {
        let from = CGPoint(x: 0, y: 0)
        let to = CGPoint(x: 100, y: 50)

        let half = from.vc_eased(toward: to, by: 0.5)
        #expect(half == CGPoint(x: 50, y: 25))

        #expect(from.vc_eased(toward: to, by: 0) == from)
        #expect(from.vc_eased(toward: to, by: 1) == to)
    }
}

/// Keeping a carried ingredient out of the reset button.
struct ResetButtonExclusionTests {

    private let button = CGPoint(x: 900, y: 700)
    private let keepOut: CGFloat = 150

    @Test func aPointOutsideTheZoneIsLeftAlone() {
        let clear = CGPoint(x: 400, y: 300)

        #expect(GameScene.pushedOut(clear, awayFrom: button, keepOut: keepOut) == clear)
    }

    /// Pushed straight out along the line it came in on, to the edge exactly.
    @Test func aPointInsideIsPushedToTheEdge() {
        let inside = CGPoint(x: 950, y: 700) // 50pt to the right of centre

        let pushed = GameScene.pushedOut(inside, awayFrom: button, keepOut: keepOut)

        #expect(abs(pushed.x - (button.x + keepOut)) < 0.001)
        #expect(abs(pushed.y - button.y) < 0.001)
    }

    /// Whatever comes out must be clear of the button, from any direction.
    @Test func nothingSurvivesInsideTheZone() {
        for angle in stride(from: 0.0, to: 2 * .pi, by: .pi / 6) {
            let inside = CGPoint(
                x: button.x + cos(angle) * 40,
                y: button.y + sin(angle) * 40
            )

            let pushed = GameScene.pushedOut(inside, awayFrom: button, keepOut: keepOut)

            #expect(pushed.vc_distance(to: button) >= keepOut - 0.001)
        }
    }

    /// Dead centre has no direction to push along — it must still come out,
    /// not divide by zero.
    @Test func deadCentreStillEscapes() {
        let pushed = GameScene.pushedOut(button, awayFrom: button, keepOut: keepOut)

        #expect(abs(pushed.vc_distance(to: button) - keepOut) < 0.001)
    }

    @Test func aZeroZoneExcludesNothing() {
        #expect(GameScene.pushedOut(button, awayFrom: button, keepOut: 0) == button)
    }
}

/// Laying the tutorial artwork out, and placing the bubbles on it.
///
/// The Skip button is a real SwiftUI button now rather than a hit area
/// measured over painted-on artwork, so there is no hotspot left to pin down.
@MainActor
struct TutorialLayoutTests {

    /// Landscape iPad — wider than the 4:3 artwork.
    private let landscape = CGSize(width: 1194, height: 834)

    /// Portrait, where the same page has to letterbox the other way.
    private let portrait = CGSize(width: 834, height: 1194)

    /// Fitted, so the whole page is always visible — nothing is cropped away,
    /// least of all the Skip button sitting near the edge.
    @Test func thePageFitsInsideTheScreen() {
        for screen in [landscape, portrait] {
            let page = TutorialView.pageRect(in: screen)

            #expect(page.width <= screen.width + 0.001)
            #expect(page.height <= screen.height + 0.001)
        }
    }

    /// Centred, and keeping the artwork's own 4:3 shape.
    @Test func thePageIsCentredAndKeepsItsAspect() {
        let page = TutorialView.pageRect(in: landscape)

        #expect(abs(page.midX - landscape.width / 2) < 0.001)
        #expect(abs(page.midY - landscape.height / 2) < 0.001)

        let drawn = TutorialView.pageSize.width / TutorialView.pageSize.height
        #expect(abs(page.width / page.height - drawn) < 0.001)
    }

    /// A screen already at 4:3 wastes nothing.
    @Test func aMatchingScreenIsFilledCompletely() {
        let exact = CGSize(width: 1366, height: 1024)
        let page = TutorialView.pageRect(in: exact)

        #expect(abs(page.width - exact.width) < 0.001)
        #expect(abs(page.height - exact.height) < 0.001)
    }

    /// Every page has to resolve to something drawable, or the walkthrough
    /// shows a blank screen the player can only tap past.
    @Test func everyPageHasArtwork() {
        for page in TutorialPage.all {
            switch page.backdrop {
            case let .still(name):
                #expect(UIImage(named: name) != nil, "missing image \(name)")
            case let .clip(name):
                #expect(
                    Bundle.main.url(forResource: name, withExtension: "mov") != nil,
                    "missing clip \(name)"
                )
            }
        }
    }

    /// Copy is resolved through the localization tables, so a page that has a
    /// line must still have one after that round trip — an empty result means
    /// the bubble renders as a blank box.
    @Test func everyCaptionResolvesToText() {
        for page in TutorialPage.all where page.message != nil {
            #expect(page.localizedMessage?.isEmpty == false,
                    "page \(page.id) resolved to nothing")
        }
    }

    /// The anchors are hand-placed off the benchmark artwork, so this is the
    /// check that one of them was not mistyped: the bubble is a fixed-size
    /// piece of art, so it has to start on the page and still fit whole.
    @Test func everyBubbleAnchorKeepsTheBubbleOnThePage() {
        let widthShare = TutorialBubble.bodySize.width / TutorialView.pageSize.width
        let heightShare = TutorialBubble.bodySize.height / TutorialView.pageSize.height

        for page in TutorialPage.all where page.message != nil {
            let anchor = page.bubbleAnchor
            #expect(anchor.x >= 0 && anchor.y >= 0, "page \(page.id) starts off-page")
            #expect(anchor.x + widthShare <= 1.001,
                    "page \(page.id) runs off the right edge")
            #expect(anchor.y + heightShare <= 1.001,
                    "page \(page.id) runs off the bottom")
        }
    }

    /// The popover artwork is used at 1×, and the page anchors are measured
    /// against the body inside it. If the asset is ever re-exported at a
    /// different size these numbers stop describing it, and every bubble
    /// silently lands in the wrong place.
    @Test func theBubbleArtworkMatchesItsMeasurements() throws {
        let art = try #require(UIImage(named: "TutorialPopover"))

        #expect(art.size == TutorialBubble.assetSize)
        #expect(TutorialBubble.bodyOrigin.x + TutorialBubble.bodySize.width
                <= TutorialBubble.assetSize.width)
        #expect(TutorialBubble.bodyOrigin.y + TutorialBubble.bodySize.height
                + TutorialBubble.tailDrop <= TutorialBubble.assetSize.height)
    }

    /// A zero-sized container must not divide by zero.
    @Test func anEmptyScreenIsHandled() {
        #expect(TutorialView.pageRect(in: .zero) == .zero)
    }
}

struct PlayAreaClampTests {

    private let screen = CGSize(width: 834, height: 1194)
    private let radius: CGFloat = 85

    /// A hand reaching past the edge of the camera's view maps outside the
    /// scene. The bubble must stop at the frame — once it leaves there is no
    /// way to reach it again.
    @Test func aBubbleDraggedPastTheEdgeStopsAtTheFrame() {
        let offLeft = GameScene.clamped(CGPoint(x: -300, y: 600), radius: radius, in: screen)
        let offRight = GameScene.clamped(CGPoint(x: 1200, y: 600), radius: radius, in: screen)
        let offBottom = GameScene.clamped(CGPoint(x: 400, y: -80), radius: radius, in: screen)
        let offTop = GameScene.clamped(CGPoint(x: 400, y: 2000), radius: radius, in: screen)

        #expect(offLeft.x == radius)
        #expect(offRight.x == screen.width - radius)
        #expect(offBottom.y == radius)
        #expect(offTop.y == screen.height - radius)
    }

    /// Clamping must not nudge a bubble that is already comfortably inside,
    /// or dragging would feel like it was fighting the hand.
    @Test func interiorPointsAreUntouched() {
        let inside = CGPoint(x: 400, y: 600)

        #expect(GameScene.clamped(inside, radius: radius, in: screen) == inside)
    }

    /// A scene narrower than two radii would build a reversed range, which
    /// traps at runtime rather than returning anything.
    @Test func aSceneSmallerThanTheBubbleDoesNotTrap() {
        let tiny = CGSize(width: 40, height: 40)

        let clamped = GameScene.clamped(CGPoint(x: 500, y: 500), radius: radius, in: tiny)

        #expect(clamped == CGPoint(x: radius, y: radius))
    }
}

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

/// Gating hands on the body they are attached to.
struct PlayerBodyMatchTests {

    /// Shoulders centred on `at`, `span` wide. Hips only when asked for —
    /// they're optional in the model because the player is often framed from
    /// the chest up.
    private func body(
        wrists: [(CGFloat, CGFloat)],
        shoulders span: CGFloat,
        at centre: CGFloat = 0.5,
        hips: Bool = false
    ) -> HandPoseManager.BodyCandidate {
        let points = wrists.map { CGPoint(x: $0.0, y: $0.1) }
        return HandPoseManager.BodyCandidate(
            head: nil, // irrelevant to wrist matching
            leftShoulder: CGPoint(x: centre - span / 2, y: 0.70),
            rightShoulder: CGPoint(x: centre + span / 2, y: 0.70),
            leftHip: hips ? CGPoint(x: centre - span / 2, y: 0.40) : nil,
            rightHip: hips ? CGPoint(x: centre + span / 2, y: 0.40) : nil,
            leftWrist: points.first,
            rightWrist: points.count > 1 ? points[1] : nil
        )
    }

    private func keep(
        hands: [(CGFloat, CGFloat)],
        bodies: [HandPoseManager.BodyCandidate],
        limit: Int = 2,
        requiredHand: HandSide? = nil
    ) -> [Int]? {
        HandPoseManager.playerHandIndices(
            handWrists: hands.map { CGPoint(x: $0.0, y: $0.1) },
            bodies: bodies,
            wristTolerance: 0.6,
            limit: limit,
            requiredHand: requiredHand
        )
    }

    /// Both of the player's hands land on their own wrists.
    @Test func bothOfThePlayersHandsAreKept() {
        let kept = keep(
            hands: [(0.40, 0.50), (0.60, 0.50)],
            bodies: [body(wrists: [(0.40, 0.50), (0.60, 0.50)], shoulders: 0.30)]
        )

        #expect(kept.map(Set.init) == Set([0, 1]))
    }

    /// One-hand mode: only the hand nearest the chosen wrist is kept, even
    /// though both of the player's hands are up.
    @Test func oneHandModeKeepsOnlyTheChosenSide() {
        let kept = keep(
            hands: [(0.40, 0.50), (0.60, 0.50)],
            bodies: [body(wrists: [(0.40, 0.50), (0.60, 0.50)], shoulders: 0.30)],
            limit: 1,
            requiredHand: .left
        )

        #expect(kept == [0], "index 0 sits on the left wrist (0.40, 0.50)")
    }

    /// The other hand is dropped exactly like a bystander's — it just isn't
    /// the wrist one-hand mode is listening to.
    @Test func oneHandModeDropsTheOtherHandEvenWithoutABystander() {
        let kept = keep(
            hands: [(0.40, 0.50), (0.60, 0.50)],
            bodies: [body(wrists: [(0.40, 0.50), (0.60, 0.50)], shoulders: 0.30)],
            limit: 1,
            requiredHand: .right
        )

        #expect(kept == [1], "index 1 sits on the right wrist (0.60, 0.50)")
    }

    /// The case geometry could not do: the player has **one** hand up, so
    /// there is nothing of theirs to compare a stray hand against. The
    /// bystander's hand is near their own wrist, so it is theirs, and it goes.
    @Test func aBystanderIsRejectedEvenWithOnlyOnePlayerHandUp() {
        let kept = keep(
            hands: [(0.45, 0.50), (0.80, 0.55)],
            bodies: [
                body(wrists: [(0.45, 0.50)], shoulders: 0.30),  // player, near
                body(wrists: [(0.80, 0.55)], shoulders: 0.12)   // bystander, far
            ]
        )

        #expect(kept == [0])
    }

    /// Even at the same distance — which defeated the geometric filter — the
    /// hand goes to whichever body's wrist it actually sits on.
    @Test func twoPeopleSideBySideAreSeparated() {
        let kept = keep(
            hands: [(0.35, 0.50), (0.62, 0.50)],
            bodies: [
                body(wrists: [(0.35, 0.50)], shoulders: 0.26),  // player
                body(wrists: [(0.62, 0.50)], shoulders: 0.25)   // neighbour
            ]
        )

        #expect(kept == [0], "the neighbour's hand belongs to the neighbour")
    }

    /// The player is whoever is nearest, not whoever Vision listed first.
    @Test func theNearestBodyIsThePlayer() {
        let kept = keep(
            hands: [(0.20, 0.50), (0.75, 0.50)],
            bodies: [
                body(wrists: [(0.20, 0.50)], shoulders: 0.10),  // far, listed first
                body(wrists: [(0.75, 0.50)], shoulders: 0.32)   // near
            ]
        )

        #expect(kept == [1])
    }

    /// A hand nowhere near any wrist is noise, not a player.
    @Test func aHandOffAnyBodyIsDropped() {
        let kept = keep(
            hands: [(0.05, 0.95)],
            bodies: [body(wrists: [(0.50, 0.50)], shoulders: 0.20)]
        )

        #expect(kept?.isEmpty == true)
    }

    /// Never more hands than the game can play with.
    @Test func neverReturnsMoreThanTheLimit() {
        let kept = keep(
            hands: [(0.40, 0.50), (0.45, 0.50), (0.50, 0.50)],
            bodies: [body(wrists: [(0.40, 0.50), (0.50, 0.50)], shoulders: 0.40)]
        )

        #expect(kept?.count == 2)
    }

    /// No shoulders in shot, no hands. A hand only counts as the player's if
    /// it can be tied to a visible body, so a cropped torso tracks nothing —
    /// the caller maps this nil straight to an empty list.
    @Test func noBodyMeansNoHands() {
        #expect(keep(hands: [(0.5, 0.5)], bodies: []) == nil)
    }

    /// The player is in frame with their hands down or out of shot. That
    /// matches nothing, and is reported as an empty list rather than as "no
    /// body" — the two are distinct even though the caller now treats them
    /// the same way.
    @Test func aPlayerWithNoVisibleWristsMatchesNothing() {
        let kept = keep(
            hands: [(0.85, 0.55)],                       // a bystander's hand
            bodies: [body(wrists: [], shoulders: 0.30)]  // player, hands down
        )

        #expect(kept == [], "empty, not nil")
    }

    /// The case called out explicitly: a bystander whose whole body is visible
    /// still loses to a nearer player framed from the chest up. Scale is
    /// shoulder span alone, so extra visible joints buy no advantage.
    @Test func aFullBodyBystanderStillLosesToTheNearerPlayer() {
        let kept = keep(
            hands: [(0.45, 0.50), (0.85, 0.50)],
            bodies: [
                body(wrists: [(0.45, 0.50)], shoulders: 0.30, at: 0.45),
                body(wrists: [(0.85, 0.50)], shoulders: 0.12, at: 0.85, hips: true)
            ]
        )

        #expect(kept == [0])
    }

    /// Only ever one body is treated as the player, whoever else is in shot.
    @Test func theNearestBodyIsTheOnlyOneChosen() {
        let bodies = [
            body(wrists: [], shoulders: 0.12, at: 0.2),
            body(wrists: [], shoulders: 0.31, at: 0.5),
            body(wrists: [], shoulders: 0.20, at: 0.8)
        ]

        #expect(HandPoseManager.nearestBody(in: bodies) == 1)
    }
}

/// The seat check the player has to pass before the game starts.
struct SeatCalibrationTests {

    /// A 400×300 box at the middle of a 1000×800 screen.
    private let frame = CGRect(x: 300, y: 250, width: 400, height: 300)

    /// Shoulders must span at least a quarter of the box.
    private var minimumSpan: CGFloat { frame.width * 0.25 }

    /// Copying the guide pose: head and shoulders in the box, both hands up
    /// beside the head. Hips sit *below* the box on purpose — the rest of the
    /// body is allowed to fall outside it.
    private func body(
        centre: CGFloat = 500,
        span: CGFloat = 200,
        shoulderY: CGFloat = 420,
        head: CGPoint? = CGPoint(x: 500, y: 320),
        wrists: [CGPoint] = [CGPoint(x: 390, y: 330), CGPoint(x: 610, y: 330)]
    ) -> HandPoseManager.BodyCandidate {
        HandPoseManager.BodyCandidate(
            head: head,
            leftShoulder: CGPoint(x: centre - span / 2, y: shoulderY),
            rightShoulder: CGPoint(x: centre + span / 2, y: shoulderY),
            leftHip: CGPoint(x: centre - span / 2, y: 700),
            rightHip: CGPoint(x: centre + span / 2, y: 700),
            leftWrist: wrists.first,
            rightWrist: wrists.count > 1 ? wrists[1] : nil
        )
    }

    /// Hips out of the box are fine — only what the game tracks has to be in.
    @Test func headShouldersAndBothHandsInTheBoxPasses() {
        #expect(body().isAligned(in: frame, minimumShoulderSpan: minimumSpan))
    }

    /// Arms down: the hands drop below the box, which is what makes the guide
    /// pose meaningful rather than decorative.
    @Test func handsDownFails() {
        let armsDown = body(wrists: [CGPoint(x: 390, y: 720), CGPoint(x: 610, y: 720)])

        #expect(!armsDown.isAligned(in: frame, minimumShoulderSpan: minimumSpan))
    }

    /// One hand up is not the pose — by default, both are required.
    @Test func onlyOneHandUpFails() {
        let oneHand = body(wrists: [CGPoint(x: 390, y: 330)])

        #expect(!oneHand.isAligned(in: frame, minimumShoulderSpan: minimumSpan))
    }

    /// One-hand mode: raising the chosen hand alone is enough.
    @Test func oneHandModePassesWithOnlyTheChosenHandUp() {
        // Left wrist only — see the `body()` default order below.
        let leftHandOnly = body(wrists: [CGPoint(x: 390, y: 330)])

        #expect(leftHandOnly.isAligned(
            in: frame, minimumShoulderSpan: minimumSpan, requiredHand: .left
        ))
    }

    /// One-hand mode still checks *which* hand — raising the other one
    /// doesn't satisfy it, otherwise the setting would mean nothing.
    @Test func oneHandModeFailsWhenTheOtherHandIsUp() {
        let leftHandOnly = body(wrists: [CGPoint(x: 390, y: 330)])

        #expect(!leftHandOnly.isAligned(
            in: frame, minimumShoulderSpan: minimumSpan, requiredHand: .right
        ))
    }

    /// No head found — the player is out of shot or turned right away.
    @Test func noHeadFails() {
        #expect(!body(head: nil).isAligned(in: frame, minimumShoulderSpan: minimumSpan))
    }

    /// Head above the box: sitting too close, so it rides out of the top.
    @Test func headAboveTheBoxFails() {
        let tooClose = body(head: CGPoint(x: 500, y: 100))

        #expect(!tooClose.isAligned(in: frame, minimumShoulderSpan: minimumSpan))
    }

    /// Shoulders off to one side, so the player is out of the box sideways.
    @Test func aBodyOffToOneSideFails() {
        #expect(!body(centre: 850).isAligned(in: frame, minimumShoulderSpan: minimumSpan))
    }

    /// Sitting too far back: everything fits, but there is too little of the
    /// player left for the tracker to work with.
    @Test func sittingTooFarAwayFails() {
        let distant = body(span: 60)

        #expect(distant.isAligned(in: frame, minimumShoulderSpan: 0), "fits the box")
        #expect(!distant.isAligned(in: frame, minimumShoulderSpan: minimumSpan))
    }

    /// `CGRect.contains` excludes the far edge, so a hand resting exactly on
    /// the bottom of the box counts as outside. Deliberate: at the boundary the
    /// player is on the verge of dropping out of frame anyway.
    @Test func aJointExactlyOnTheEdgeIsOutside() {
        let onTheLine = body(wrists: [CGPoint(x: 390, y: frame.maxY), CGPoint(x: 610, y: 330)])

        #expect(!onTheLine.isAligned(in: frame, minimumShoulderSpan: minimumSpan))
    }
}

/// The upper-body skeleton that gets drawn.
struct BodySkeletonTests {

    private func body(hips: Bool) -> HandPoseManager.BodyCandidate {
        HandPoseManager.BodyCandidate(
            head: CGPoint(x: 0.5, y: 0.85), // never drawn — see the test below
            leftShoulder: CGPoint(x: 0.4, y: 0.7),
            rightShoulder: CGPoint(x: 0.6, y: 0.7),
            leftHip: hips ? CGPoint(x: 0.42, y: 0.4) : nil,
            rightHip: hips ? CGPoint(x: 0.58, y: 0.4) : nil,
            leftWrist: nil,
            rightWrist: nil
        )
    }

    /// Framed from the chest up: just the shoulder line, no dangling bones to
    /// hips that were never seen.
    @Test func shouldersAloneDrawOneBone() {
        #expect(body(hips: false).chains == [[CGPoint(x: 0.4, y: 0.7), CGPoint(x: 0.6, y: 0.7)]])
    }

    /// Hips in shot close the torso: shoulder line, both sides, hip line.
    @Test func hipsCloseTheTorso() {
        #expect(body(hips: true).chains.count == 4)
    }

    /// Legs are never read, so nothing below the hips can ever be drawn.
    @Test func nothingIsDrawnBelowTheHips() {
        let lowest = body(hips: true).chains.flatMap { $0 }.map(\.y).min()

        #expect(lowest == 0.4, "hip line is the bottom of the skeleton")
    }

    /// The head drives the seat check but is not part of the skeleton, so it
    /// must never turn up in the drawn chains.
    @Test func theHeadIsNotDrawn() {
        let drawn = Set(body(hips: true).chains.flatMap { $0 })

        #expect(!drawn.contains(CGPoint(x: 0.5, y: 0.85)))
    }
}

struct HandIdentityTests {

    private let radius: CGFloat = 0.28

    /// The whole point of the matcher: Vision returns observations in no
    /// guaranteed order, so the same two hands can arrive swapped between
    /// frames. If identity followed array position, each hand would inherit
    /// whatever the other was dragging.
    @Test func reorderedObservationsKeepTheirIdentities() {
        let previous = [CGPoint(x: 0.2, y: 0.5),   // hand 0, left
                        CGPoint(x: 0.8, y: 0.5)]   // hand 1, right
        // Same two hands, reported in the opposite order this frame.
        let incoming = [CGPoint(x: 0.81, y: 0.51),
                        CGPoint(x: 0.19, y: 0.49)]

        let assignments = HandPoseManager.matchAssignments(
            newPositions: incoming, previousPositions: previous, radius: radius
        )

        #expect(assignments == [1, 0])
    }

    @Test func stationaryHandsKeepTheirIndices() {
        let previous = [CGPoint(x: 0.3, y: 0.4), CGPoint(x: 0.7, y: 0.6)]
        let assignments = HandPoseManager.matchAssignments(
            newPositions: previous, previousPositions: previous, radius: radius
        )
        #expect(assignments == [0, 1])
    }

    /// Each previous hand can only be claimed once, or one hand appearing in
    /// two places would eat both slots and orphan the other.
    @Test func onePreviousHandIsClaimedOnlyOnce() {
        let previous = [CGPoint(x: 0.5, y: 0.5)]
        let incoming = [CGPoint(x: 0.51, y: 0.5), CGPoint(x: 0.52, y: 0.5)]

        let assignments = HandPoseManager.matchAssignments(
            newPositions: incoming, previousPositions: previous, radius: radius
        )

        #expect(assignments == [0, nil], "second hand must be treated as new")
    }

    /// A hand that appears far from anything known is a new hand, not a
    /// teleporting old one.
    @Test func distantHandCountsAsNew() {
        let assignments = HandPoseManager.matchAssignments(
            newPositions: [CGPoint(x: 0.9, y: 0.9)],
            previousPositions: [CGPoint(x: 0.1, y: 0.1)],
            radius: radius
        )
        #expect(assignments == [nil])
    }

    @Test func firstFrameHasNothingToMatchAgainst() {
        let assignments = HandPoseManager.matchAssignments(
            newPositions: [CGPoint(x: 0.3, y: 0.3), CGPoint(x: 0.7, y: 0.7)],
            previousPositions: [],
            radius: radius
        )
        #expect(assignments == [nil, nil])
    }
}

@MainActor
struct GameLoopTests {

    @Test func recipesCarryTheSpecifiedScores() {
        #expect(Recipe.chickenMayonnaise.scoreValue == 15)
        #expect(Recipe.chickenCheese.scoreValue == 15)
        #expect(Recipe.salad.scoreValue == 20)
        #expect(Recipe.chickenGeprek.scoreValue == 25)
    }

    /// Swiping down retries the *same* dish — it must not skip to another
    /// recipe or touch the score.
    @Test func discardKeepsTheSameRecipeAndScore() {
        let manager = GameStateManager(recipes: [.chickenGeprek])
        manager.start()
        manager.addIngredientToPlate(.cheese) // wrong ingredient
        #expect(manager.plateContents.count == 1)

        manager.discardPlate()

        #expect(manager.plateContents.isEmpty)
        #expect(manager.currentRecipe == .chickenGeprek)
        #expect(manager.totalDishesServed == 0)
    }

    /// A stray downward swipe over an empty plate must not bump the token, or
    /// GameScene would replay the fly-away animation and respawn the table
    /// mid-round.
    @Test func discardingAnEmptyPlateDoesNothing() {
        let manager = GameStateManager(recipes: [.salad])
        manager.start()
        let tokenBefore = manager.discardToken

        manager.discardPlate()

        #expect(manager.discardToken == tokenBefore)
    }

    @Test func discardBumpsTokenSoTheSceneCanAnimate() {
        let manager = GameStateManager(recipes: [.salad])
        manager.start()
        manager.addIngredientToPlate(.tomato)
        let tokenBefore = manager.discardToken

        manager.discardPlate()

        #expect(manager.discardToken == tokenBefore + 1)
    }

    /// The "Play Again does nothing" bug: restarting has to reset the score and
    /// the plate, and bump the token GameScene keys its board wipe off.
    ///
    /// Leaves `state` at `.idle` rather than `.cooking` — a replay has to sit
    /// through the seat check and countdown again, and it's `start()` that
    /// actually resumes play once that beat finishes (see below).
    @Test func restartResetsEverythingAndBumpsResetToken() {
        let manager = GameStateManager(recipes: [.chickenMayonnaise])
        manager.start()
        manager.addIngredientToPlate(.chicken)
        let tokenBefore = manager.resetToken

        manager.restart()

        #expect(manager.plateContents.isEmpty)
        #expect(manager.totalDishesServed == 0)
        #expect(manager.speedBonus == 0)
        #expect(manager.lives == manager.startingLives)
        #expect(manager.elapsedTime == 0)
        #expect(manager.state == .idle)
        #expect(manager.resetToken == tokenBefore + 1,
                "GameScene clears the board off this token; without it the old ingredients stay")
    }

    /// `restart()` alone must not resume play — GameplayView's countdown is
    /// what calls `start()` once it finishes, same as the very first run.
    @Test func restartDoesNotResumePlayOnItsOwn() {
        let manager = GameStateManager(recipes: [.chickenMayonnaise])
        manager.start()
        manager.restart()

        #expect(manager.state == .idle)

        manager.start()
        #expect(manager.state == .cooking)
    }

    @Test func servingCountsTheDishThatWasServed() async throws {
        let manager = GameStateManager(recipes: [.chickenGeprek])
        manager.start()
        for ingredient in Recipe.chickenGeprek.ingredients {
            manager.addIngredientToPlate(ingredient)
        }
        #expect(manager.state == .dishComplete)

        try await Task.sleep(for: .milliseconds(1200)) // dish reveal beat
        #expect(manager.state == .waitingToServe)

        manager.serveDish()

        #expect(manager.totalDishesServed == 1)
        #expect(manager.dishesByType[Recipe.chickenGeprek.finishedDishImageName] == 1,
                "counted against the dish that was actually served")
    }

    /// Serving is gated on the bell having rung. The plate passes over plenty
    /// of screen while ingredients are still being fetched, and none of that
    /// may count as a delivery.
    @Test func servingBeforeTheBellDoesNothing() {
        let manager = GameStateManager(recipes: [.chickenMayonnaise])
        manager.start()
        #expect(manager.state == .cooking)

        manager.serveDish()

        #expect(manager.totalDishesServed == 0)
        #expect(manager.state == .cooking, "still cooking")
    }

    /// The bell picks an edge, and that edge is what the scene carries the
    /// plate toward. It has to clear once the dish is gone, or the next round
    /// would start with a stale target.
    @Test func theBellRingsOnOneSideAndClearsAfterServing() async throws {
        let manager = GameStateManager(recipes: [.chickenMayonnaise, .salad])
        manager.start()
        for ingredient in manager.currentRecipe.ingredients {
            manager.addIngredientToPlate(ingredient)
        }
        try await Task.sleep(for: .milliseconds(1200))

        #expect(manager.state == .waitingToServe)
        let side = try #require(manager.bellSide)
        #expect(side == .left || side == .right)

        manager.serveDish()

        #expect(manager.bellSide == nil)
        #expect(manager.state == .cooking)
    }

    /// A wrong ingredient must not complete the dish.
    @Test func wrongIngredientDoesNotComplete() {
        let manager = GameStateManager(recipes: [.chickenMayonnaise])
        manager.start()
        manager.addIngredientToPlate(.chicken)
        manager.addIngredientToPlate(.cheese) // should have been mayo
        #expect(manager.state == .cooking)
    }
}

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

struct DishTimeLimitTests {

    /// Each dish carries its own assembly budget, so pin the shipped numbers.
    ///
    /// They all sit at 30s today, and the difficulty ramp squeezes that as the
    /// run goes on rather than the recipes differing from each other. The
    /// field is still per-recipe, so a fiddly dish can be given more room
    /// without touching the others.
    @Test func everyRecipeDeclaresItsOwnLimit() {
        #expect(Recipe.chickenMayonnaise.timeLimit == 10)
        #expect(Recipe.chickenCheese.timeLimit == 10)
        #expect(Recipe.chickenGeprek.timeLimit == 10)
        #expect(Recipe.salad.timeLimit == 10)
    }

    /// Every recipe must be worth some time, or it would fail the instant it
    /// was dealt.
    @Test func everyRecipeGetsTimeOnTheClock() {
        for recipe in Recipe.all {
            #expect(recipe.timeLimit > 0, "\(recipe.name) has no time limit")
        }
    }
}

@MainActor
struct LivesTests {

    /// Running the clock out costs a life but keeps the run going, with the
    /// score intact — the player is being set back, not reset.
    @Test func aTimedOutDishCostsOneLifeAndDealsAnother() {
        let manager = GameStateManager(recipes: Recipe.all)
        manager.start()
        let recipeBefore = manager.currentRecipe

        manager.failDish()

        #expect(manager.lives == manager.startingLives - 1)
        #expect(manager.totalDishesServed == 0)
        #expect(manager.state == .cooking)
        #expect(manager.currentRecipe != recipeBefore)
        #expect(manager.plateContents.isEmpty)
    }

    /// The scene has no state change to notice here — a dish can time out
    /// while already `.cooking` — so the token is the only signal that the
    /// board must be wiped for the new recipe.
    @Test func aTimedOutDishBumpsTheResetToken() {
        let manager = GameStateManager(recipes: Recipe.all)
        manager.start()
        let tokenBefore = manager.resetToken

        manager.failDish()

        #expect(manager.resetToken == tokenBefore + 1)
    }

    /// Losing a life wipes the board but the run carries on, so the player
    /// must not be dropped back into a 3-2-1-GO! countdown. `runToken` is what
    /// GameplayView keys that countdown off, and only `restart()` bumps it.
    @Test func aTimedOutDishDoesNotBumpTheRunToken() {
        let manager = GameStateManager(recipes: Recipe.all)
        manager.start()
        let runBefore = manager.runToken

        manager.failDish()

        #expect(manager.state == .cooking, "still playing, just a life down")
        #expect(manager.runToken == runBefore, "no countdown mid-run")
    }

    /// Replay is the other half of that rule: a fresh run *does* get the
    /// countdown back.
    @Test func restartBumpsTheRunToken() {
        let manager = GameStateManager(recipes: Recipe.all)
        manager.start()
        let runBefore = manager.runToken

        manager.restart()

        #expect(manager.runToken == runBefore + 1)
    }

    /// The run ends on the last life, and only then — this is the sole way to
    /// reach `.gameOver` now that the round countdown is gone.
    @Test func losingTheLastLifeEndsTheRun() {
        let manager = GameStateManager(recipes: Recipe.all, startingLives: 2)
        manager.start()

        manager.failDish()
        #expect(manager.state == .cooking, "one life left, still playing")

        manager.failDish()

        #expect(manager.lives == 0)
        #expect(manager.state == .gameOver)
    }

    /// Nothing should keep draining lives after the run is over.
    @Test func failingAfterGameOverChangesNothing() {
        let manager = GameStateManager(recipes: Recipe.all, startingLives: 1)
        manager.start()
        manager.failDish()
        #expect(manager.state == .gameOver)

        manager.failDish()

        #expect(manager.lives == 0, "lives must not go negative")
    }

    /// The clock covers assembly only. Once the plate matches, the ring goes
    /// away and the dish can no longer time out — otherwise a slow swipe would
    /// cost the life the player just cooked their way out of.
    @Test func theClockStopsOnceTheDishIsAssembled() {
        let manager = GameStateManager(recipes: [.chickenMayonnaise])
        manager.start()
        #expect(manager.isTimingDish)

        for ingredient in Recipe.chickenMayonnaise.ingredients {
            manager.addIngredientToPlate(ingredient)
        }

        #expect(manager.state == .dishComplete)
        #expect(!manager.isTimingDish, "serving is not timed")
    }

    /// ...and picks up again for the next dish, with that dish's own budget.
    @Test func theClockRestartsForTheNextRecipe() async throws {
        let manager = GameStateManager(recipes: [.chickenMayonnaise, .salad])
        manager.start()
        for ingredient in manager.currentRecipe.ingredients {
            manager.addIngredientToPlate(ingredient)
        }
        try await Task.sleep(for: .milliseconds(1200))
        #expect(!manager.isTimingDish)

        manager.serveDish()

        #expect(manager.isTimingDish, "the next dish is on the clock")
        #expect(manager.dishTimeLimit == manager.currentRecipe.timeLimit)
        #expect(manager.dishTimeFraction > 0.9, "a fresh dish starts near full")
    }

    /// Serving is scored and does *not* cost a life, so a clean run keeps all
    /// three hearts however long it lasts.
    @Test func servingDoesNotCostALife() async throws {
        let manager = GameStateManager(recipes: [.chickenMayonnaise, .chickenCheese])
        manager.start()
        for ingredient in manager.currentRecipe.ingredients {
            manager.addIngredientToPlate(ingredient)
        }
        try await Task.sleep(for: .milliseconds(1200))

        manager.serveDish()

        #expect(manager.lives == manager.startingLives)
        #expect(manager.totalDishesServed > 0)
    }

    /// The bell has rung and the serve window is counting down. It is a real
    /// deadline: let it lapse and the order is abandoned, same as a dish that
    /// never got assembled.
    @Test func theServeWindowStartsFullWhenTheBellRings() async throws {
        let manager = GameStateManager(recipes: [.chickenMayonnaise])
        manager.start()
        for ingredient in manager.currentRecipe.ingredients {
            manager.addIngredientToPlate(ingredient)
        }

        #expect(!manager.isTimingServe, "still showing the finished dish")

        try await Task.sleep(for: .milliseconds(1200))

        #expect(manager.isTimingServe)
        #expect(manager.serveTimeFraction > 0.9,
                "the reveal beat must not eat into the player's window")
    }

    /// The dish clock and the serve clock never run at the same time — each
    /// only applies in its own phase, so a waiting order can't be failed twice.
    @Test func onlyOneClockRunsAtATime() async throws {
        let manager = GameStateManager(recipes: [.chickenMayonnaise])
        manager.start()

        #expect(manager.isTimingDish)
        #expect(!manager.isTimingServe)

        for ingredient in manager.currentRecipe.ingredients {
            manager.addIngredientToPlate(ingredient)
        }
        try await Task.sleep(for: .milliseconds(1200))

        #expect(!manager.isTimingDish)
        #expect(manager.isTimingServe)
    }

    /// Every five *served* dishes the assembly clock tightens by 1.25×, so the
    /// same recipe has to be built in 80% of the time it had a tier earlier.
    @Test func difficultyRampsEveryFiveServedDishes() async throws {
        let manager = GameStateManager(recipes: [.chickenMayonnaise, .salad])
        manager.start()

        func serveOneDish() async throws {
            for ingredient in manager.currentRecipe.ingredients {
                manager.addIngredientToPlate(ingredient)
            }
            // Long enough for the reveal beat to hand over to the swipe cue.
            try await Task.sleep(for: .milliseconds(1200))
            manager.serveDish()
        }

        // Dishes 1–4 stay on the base budget for whatever recipe is up.
        for _ in 0..<4 { try await serveOneDish() }
        #expect(manager.dishesCompleted == 4)
        #expect(manager.dishTimeLimit == manager.currentRecipe.timeLimit)

        // The 5th serve crosses the first speed-up step, so the dish that
        // starts right after gets 1 / 1.25 of its own recipe's time.
        try await serveOneDish()
        #expect(manager.dishesCompleted == 5)
        #expect(abs(manager.dishTimeLimit - manager.currentRecipe.timeLimit / 1.25) < 0.0001)
    }

    /// A timed-out dish is not "done", so it must not advance the ramp.
    @Test func failedDishesDoNotRampDifficulty() {
        let manager = GameStateManager(recipes: [.chickenMayonnaise, .salad])
        manager.start()

        manager.failDish()

        #expect(manager.dishesCompleted == 0)
        #expect(manager.dishTimeLimit == manager.currentRecipe.timeLimit)
    }
}

struct RecipeMatchingTests {

    @Test func exactMultisetMatches() {
        #expect(GameStateManager.matches(plateContents: [.chicken, .chili, .cucumber], recipe: .chickenGeprek))
    }

    @Test func orderDoesNotMatter() {
        #expect(GameStateManager.matches(plateContents: [.cucumber, .chicken, .chili], recipe: .chickenGeprek))
    }

    @Test func extraIngredientFails() {
        #expect(!GameStateManager.matches(plateContents: [.lettuce, .cucumber, .tomato, .mayonnaise, .cheese], recipe: .salad))
    }

    @Test func missingIngredientFails() {
        #expect(!GameStateManager.matches(plateContents: [.lettuce, .cucumber], recipe: .salad))
    }

    /// Chicken Mayonnaise and Chicken Cheese share a chicken but differ by one item, so a
    /// plate for one must never satisfy the other.
    @Test func similarRecipesDoNotCrossMatch() {
        #expect(!GameStateManager.matches(plateContents: [.chicken, .cheese], recipe: .chickenMayonnaise))
        #expect(!GameStateManager.matches(plateContents: [.chicken, .mayonnaise], recipe: .chickenCheese))
    }

    /// Every recipe's own ingredient list must satisfy it — cheap guard against
    /// a typo when the menu changes.
    @Test func everyRecipeMatchesItself() {
        for recipe in Recipe.all {
            #expect(GameStateManager.matches(plateContents: recipe.ingredients, recipe: recipe))
        }
    }

    /// Each recipe needs at least two decoys available, or the trash bin has
    /// nothing to do that round.
    @Test func everyRecipeLeavesDecoysAvailable() {
        for recipe in Recipe.all {
            let decoys = Ingredient.allCases.filter { !recipe.ingredients.contains($0) }
            #expect(decoys.count >= 2, "\(recipe.name) leaves only \(decoys.count) decoys")
        }
    }
}
