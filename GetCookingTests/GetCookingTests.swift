//
//  GetCookingTests.swift
//  GetCookingTests
//
//  Created by Kyky on 11/08/26.
//

import Testing
import CoreGraphics
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
        #expect(TrimmedArt.image(named: GameArt.bubble) != nil)
        #expect(TrimmedArt.image(named: GameArt.plate) != nil)
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

struct FistClassifierTests {

    private let wrist = CGPoint.zero
    private let palmLength: CGFloat = 1.0
    private let threshold: CGFloat = 1.5

    /// An open hand puts each tip ~2 palm-lengths from the wrist.
    @Test func openHandCountsEveryFinger() {
        let tips = [2.0, 2.1, 1.95, 1.8].map { CGPoint(x: 0, y: $0) }

        let count = HandPoseManager.extendedFingerCount(
            wrist: wrist, fingertips: tips, palmLength: palmLength, threshold: threshold
        )

        #expect(count == 4)
    }

    /// A fist curls the tips back to roughly the knuckle line (~1 palm length).
    /// The old tip/PIP ratio test scored a *straight* finger at only ~1.33, so
    /// it never cleared 1.5 and every hand read as a permanent fist.
    @Test func closedFistCountsNoFingers() {
        let tips = [1.0, 1.1, 0.95, 0.9].map { CGPoint(x: 0, y: $0) }

        let count = HandPoseManager.extendedFingerCount(
            wrist: wrist, fingertips: tips, palmLength: palmLength, threshold: threshold
        )

        #expect(count == 0)
    }

    /// Scale-free: the same pose twice as far from the camera must classify
    /// identically, since every distance is divided by palm length.
    @Test func classificationIsIndependentOfDistanceFromCamera() {
        let near = [2.0, 2.1, 1.95, 1.8].map { CGPoint(x: 0, y: $0) }
        let far = near.map { CGPoint(x: $0.x / 2, y: $0.y / 2) }

        let nearCount = HandPoseManager.extendedFingerCount(
            wrist: wrist, fingertips: near, palmLength: palmLength, threshold: threshold
        )
        let farCount = HandPoseManager.extendedFingerCount(
            wrist: wrist, fingertips: far, palmLength: palmLength / 2, threshold: threshold
        )

        #expect(nearCount == farCount)
    }

    @Test func missingPalmMeasurementDoesNotReportExtendedFingers() {
        let count = HandPoseManager.extendedFingerCount(
            wrist: wrist, fingertips: [CGPoint(x: 0, y: 2)], palmLength: 0, threshold: threshold
        )

        #expect(count == 0)
    }
}

struct SwipeDetectionTests {

    /// Same numbers the manager ships with.
    private func detect(from start: CGPoint, to end: CGPoint, over duration: TimeInterval) -> SwipeDirection? {
        HandPoseManager.swipeDirection(
            from: start, to: end, over: duration,
            minimumDistance: 0.10, horizontalSpeed: 0.9, dominance: 1.25
        )
    }

    /// A casual flick — 18% of the frame in a sixth of a second — has to land.
    /// This is the whole point of the change: it was below the old 1.8 bar.
    @Test func casualHorizontalFlickRegisters() {
        #expect(detect(from: CGPoint(x: 0.4, y: 0.5), to: CGPoint(x: 0.58, y: 0.5), over: 0.16) == .right)
        #expect(detect(from: CGPoint(x: 0.58, y: 0.5), to: CGPoint(x: 0.4, y: 0.5), over: 0.16) == .left)
    }

    /// Vertical motion is never a serve — reaching down for the bowl or up for
    /// a high bubble must not fling the dish away.
    @Test func verticalFlicksAreNotServes() {
        #expect(detect(from: CGPoint(x: 0.5, y: 0.6), to: CGPoint(x: 0.5, y: 0.42), over: 0.16) == nil)
        #expect(detect(from: CGPoint(x: 0.5, y: 0.42), to: CGPoint(x: 0.5, y: 0.6), over: 0.16) == nil)
    }

    /// Slow drift covers the distance but not the speed — reaching across the
    /// table must not read as a swipe.
    @Test func slowDriftIsNotASwipe() {
        #expect(detect(from: CGPoint(x: 0.3, y: 0.5), to: CGPoint(x: 0.6, y: 0.5), over: 1.5) == nil)
    }

    /// Fast but tiny: jitter over a couple of frames clears the speed bar
    /// easily, which is why a net-distance bar exists too.
    @Test func fastJitterIsNotASwipe() {
        #expect(detect(from: CGPoint(x: 0.5, y: 0.5), to: CGPoint(x: 0.52, y: 0.5), over: 0.05) == nil)
    }

    /// A 45° flick belongs to neither axis; acting on it would make serving and
    /// discarding fire interchangeably.
    @Test func diagonalFlickIsRejected() {
        #expect(detect(from: CGPoint(x: 0.4, y: 0.6), to: CGPoint(x: 0.6, y: 0.4), over: 0.16) == nil)
    }

    @Test func tooShortAWindowIsIgnored() {
        #expect(detect(from: CGPoint(x: 0.3, y: 0.5), to: CGPoint(x: 0.9, y: 0.5), over: 0.01) == nil)
    }
}

struct ClapDetectorTests {

    private let plate = CGPoint(x: 500, y: 200)
    private let plateReach: CGFloat = 170
    private let span: CGFloat = 100

    /// Hands start apart (arming the detector) then come together over the bowl.
    private func clap(
        _ detector: inout ClapDetector,
        at centre: CGPoint,
        separation: CGFloat,
        empty: Bool = true,
        now: TimeInterval
    ) -> Bool {
        detector.update(
            left: CGPoint(x: centre.x - separation / 2, y: centre.y),
            right: CGPoint(x: centre.x + separation / 2, y: centre.y),
            span: span, bothHandsEmpty: empty,
            target: plate, targetRadius: plateReach, now: now
        )
    }

    @Test func handsComingTogetherOverThePlateFires() {
        var detector = ClapDetector()
        _ = clap(&detector, at: plate, separation: 300, now: 0)      // apart → arms
        #expect(clap(&detector, at: plate, separation: 40, now: 0.3))
    }

    /// Same clap, but away from the bowl. The gesture is deliberately local so
    /// hands meeting anywhere else during play can't wipe the plate.
    @Test func clappingAwayFromThePlateDoesNothing() {
        var detector = ClapDetector()
        let elsewhere = CGPoint(x: 500, y: 900)
        _ = clap(&detector, at: elsewhere, separation: 300, now: 0)
        #expect(!clap(&detector, at: elsewhere, separation: 40, now: 0.3))
    }

    /// Both hands ferrying ingredients into the bowl end up close together over
    /// the plate — the clap pose exactly. Filling the plate must not bin it.
    @Test func handsHoldingIngredientsNeverClap() {
        var detector = ClapDetector()
        _ = clap(&detector, at: plate, separation: 300, empty: false, now: 0)
        #expect(!clap(&detector, at: plate, separation: 40, empty: false, now: 0.3))
    }

    /// Holding the hands together must fire once, not every frame.
    @Test func heldTogetherFiresOnlyOnce() {
        var detector = ClapDetector()
        _ = clap(&detector, at: plate, separation: 300, now: 0)
        #expect(clap(&detector, at: plate, separation: 40, now: 0.3))
        #expect(!clap(&detector, at: plate, separation: 40, now: 0.35))
        #expect(!clap(&detector, at: plate, separation: 40, now: 2.0), "still not re-armed")
    }

    /// Parting the hands and clapping again is a second discard.
    @Test func separatingReArmsTheGesture() {
        var detector = ClapDetector()
        _ = clap(&detector, at: plate, separation: 300, now: 0)
        #expect(clap(&detector, at: plate, separation: 40, now: 0.3))
        _ = clap(&detector, at: plate, separation: 300, now: 1.5)    // apart again
        #expect(clap(&detector, at: plate, separation: 40, now: 1.8))
    }

    /// Starting with the hands already together must not fire — otherwise
    /// simply raising both hands into frame would discard the plate.
    @Test func handsAlreadyTogetherOnFirstFrameDoNotFire() {
        var detector = ClapDetector()
        #expect(!clap(&detector, at: plate, separation: 40, now: 0))
    }

    /// A hand leaving frame disarms, so the gesture can't complete across a
    /// gap where only one hand was visible.
    @Test func disarmingBlocksACompletingClap() {
        var detector = ClapDetector()
        _ = clap(&detector, at: plate, separation: 300, now: 0)
        detector.disarm()
        #expect(!clap(&detector, at: plate, separation: 40, now: 0.3))
    }

    /// Distances scale with apparent hand size, so the same gesture works up
    /// close and far away.
    @Test func thresholdsScaleWithHandSize() {
        var far = ClapDetector()
        let smallSpan: CGFloat = 40
        func step(_ separation: CGFloat, _ now: TimeInterval) -> Bool {
            far.update(
                left: CGPoint(x: plate.x - separation / 2, y: plate.y),
                right: CGPoint(x: plate.x + separation / 2, y: plate.y),
                span: smallSpan, bothHandsEmpty: true,
                target: plate, targetRadius: plateReach, now: now
            )
        }
        _ = step(120, 0)                       // 3× span apart → arms
        #expect(step(20, 0.3))                 // 0.5× span → clap
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
        #expect(Recipe.ayamMayo.scoreValue == 15)
        #expect(Recipe.ayamKeju.scoreValue == 15)
        #expect(Recipe.salad.scoreValue == 20)
        #expect(Recipe.ayamGeprek.scoreValue == 25)
    }

    /// Swiping down retries the *same* dish — it must not skip to another
    /// recipe or touch the score.
    @Test func discardKeepsTheSameRecipeAndScore() {
        let manager = GameStateManager(recipes: [.ayamGeprek])
        manager.start()
        manager.addIngredientToPlate(.keju) // wrong ingredient
        #expect(manager.plateContents.count == 1)

        manager.discardPlate()

        #expect(manager.plateContents.isEmpty)
        #expect(manager.currentRecipe == .ayamGeprek)
        #expect(manager.score == 0)
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
        manager.addIngredientToPlate(.tomat)
        let tokenBefore = manager.discardToken

        manager.discardPlate()

        #expect(manager.discardToken == tokenBefore + 1)
    }

    /// The "Play Again does nothing" bug: restarting has to reset the score and
    /// the plate, and bump the token GameScene keys its board wipe off.
    @Test func restartResetsEverythingAndBumpsResetToken() {
        let manager = GameStateManager(recipes: [.ayamMayo])
        manager.start()
        manager.addIngredientToPlate(.ayam)
        let tokenBefore = manager.resetToken

        manager.restart()

        #expect(manager.plateContents.isEmpty)
        #expect(manager.score == 0)
        #expect(manager.remainingTime == manager.roundDuration)
        #expect(manager.state == .cooking)
        #expect(manager.resetToken == tokenBefore + 1,
                "GameScene clears the board off this token; without it the old ingredients stay")
    }

    @Test func servingAwardsTheRecipesOwnScore() async throws {
        let manager = GameStateManager(recipes: [.ayamGeprek])
        manager.start()
        for ingredient in Recipe.ayamGeprek.ingredients {
            manager.addIngredientToPlate(ingredient)
        }
        #expect(manager.state == .dishComplete)

        try await Task.sleep(for: .milliseconds(1200)) // dish reveal beat
        #expect(manager.state == .waitingForSwipe)

        let cue = try #require(manager.swipeCueDirection)
        manager.handleSwipe(cue)

        #expect(manager.score == 25, "Ayam Geprek is worth 25, not a flat 1")
    }

    @Test func swipingTheWrongWayScoresNothing() async throws {
        let manager = GameStateManager(recipes: [.ayamMayo])
        manager.start()
        for ingredient in Recipe.ayamMayo.ingredients {
            manager.addIngredientToPlate(ingredient)
        }
        try await Task.sleep(for: .milliseconds(1200))

        let cue = try #require(manager.swipeCueDirection)
        manager.handleSwipe(cue == .left ? .right : .left)

        #expect(manager.score == 0)
        #expect(manager.state == .waitingForSwipe, "still waiting for the right swipe")
    }

    /// A wrong ingredient must not complete the dish.
    @Test func wrongIngredientDoesNotComplete() {
        let manager = GameStateManager(recipes: [.ayamMayo])
        manager.start()
        manager.addIngredientToPlate(.ayam)
        manager.addIngredientToPlate(.keju) // should have been mayo
        #expect(manager.state == .cooking)
    }
}

struct RecipeMatchingTests {

    @Test func exactMultisetMatches() {
        #expect(GameStateManager.matches(plateContents: [.ayam, .sambal, .timun], recipe: .ayamGeprek))
    }

    @Test func orderDoesNotMatter() {
        #expect(GameStateManager.matches(plateContents: [.timun, .ayam, .sambal], recipe: .ayamGeprek))
    }

    @Test func extraIngredientFails() {
        #expect(!GameStateManager.matches(plateContents: [.selada, .timun, .tomat, .mayonaise, .keju], recipe: .salad))
    }

    @Test func missingIngredientFails() {
        #expect(!GameStateManager.matches(plateContents: [.selada, .timun], recipe: .salad))
    }

    /// Ayam Mayo and Ayam Keju share a chicken but differ by one item, so a
    /// plate for one must never satisfy the other.
    @Test func similarRecipesDoNotCrossMatch() {
        #expect(!GameStateManager.matches(plateContents: [.ayam, .keju], recipe: .ayamMayo))
        #expect(!GameStateManager.matches(plateContents: [.ayam, .mayonaise], recipe: .ayamKeju))
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
