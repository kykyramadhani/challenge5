//
//  SeatCalibrationTests.swift
//  PlayFeatTests
//
//  Split out of GetCookingTests.swift (created by Kyky on 11/08/26).
//

import Testing
import Foundation
import CoreGraphics
@testable import PlayFeat

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
    ) -> HumanBodyPoseManager.BodyCandidate {
        HumanBodyPoseManager.BodyCandidate(
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
            in: frame, minimumShoulderSpan: minimumSpan, mode: OneHandMode(hand: .left)
        ))
    }

    /// One-hand mode still checks *which* hand — raising the other one
    /// doesn't satisfy it, otherwise the setting would mean nothing.
    @Test func oneHandModeFailsWhenTheOtherHandIsUp() {
        let leftHandOnly = body(wrists: [CGPoint(x: 390, y: 330)])

        #expect(!leftHandOnly.isAligned(
            in: frame, minimumShoulderSpan: minimumSpan, mode: OneHandMode(hand: .right)
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
