//
//  PlayerBodyMatchTests.swift
//  PlayFeatTests
//
//  Split out of GetCookingTests.swift (created by Kyky on 11/08/26).
//

import Testing
import Foundation
import CoreGraphics
@testable import PlayFeat

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
        mode: any HandInputMode = TwoHandMode()
    ) -> [Int]? {
        HandPoseManager.playerHandIndices(
            handWrists: hands.map { CGPoint(x: $0.0, y: $0.1) },
            bodies: bodies,
            wristTolerance: 0.6,
            limit: limit,
            mode: mode
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
            mode: OneHandMode(hand: .left)
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
            mode: OneHandMode(hand: .right)
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
