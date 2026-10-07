//
//  ScriptedHandInput.swift
//  PlayFeatTests
//
//  A hand the test moves itself, instead of one read from the camera. Lets a
//  GameScene be played in a unit test.
//

import CoreGraphics
@testable import PlayFeat

@MainActor
final class ScriptedHandInput: HandInputSource {
    private(set) var hands: [HandData] = []

    /// Positions are already in view space, so no camera mapping is needed.
    func cursor(for hand: HandData, in size: CGSize) -> CGPoint { hand.cursorPosition }

    /// Only the cursor is used for touching; a scripted hand has no skeleton.
    func jointPoints(for hand: HandData, in size: CGSize) -> [CGPoint] { [] }

    /// Shows one hand at `point` (view space, origin top-left), closed into a
    /// fist to grab or open to let go.
    func placeHand(at point: CGPoint, closed: Bool) {
        hands = [HandData(
            id: 0,
            cursorPosition: point,
            isOpenHand: !closed,
            isClosedFist: closed,
            skeleton: []
        )]
    }

    /// The hand leaves the frame.
    func removeHand() {
        hands = []
    }
}
