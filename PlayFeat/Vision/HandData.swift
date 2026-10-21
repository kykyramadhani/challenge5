//
//  HandData.swift
//  PlayFeat
//
//  One tracked hand as published to the UI and the scenes: where it is, whether
//  it is pinching, which of the player's hands it is, and how sure the tracker
//  is that it is really there right now.
//

import SwiftUI

/// One tracked hand, as published to the UI and the scene.
///
/// `id` is stable across frames — see `HandIdentityTracker`. Without that,
/// two-handed play breaks the moment Vision reorders its observations, because
/// each hand would inherit the other's grab.
nonisolated struct HandData: Identifiable, Equatable {
    let id: Int
    /// Palm centre in *normalized Vision space* (origin bottom-left, 0...1).
    var cursorPosition: CGPoint
    /// Not grabbing. Anything that isn't an active thumb-to-index-finger
    /// pinch is open, a clenched fist included.
    var isOpenHand: Bool
    /// Grabbing: thumb tip and index-finger tip pinched together.
    var isClosedFist: Bool
    /// One chain of joints per finger (thumb → little), normalized Vision space.
    var skeleton: [[CGPoint]]
    /// The player's own left or right hand, or nil while the tracker isn't
    /// sure. Anatomical, so it doesn't depend on the preview being mirrored.
    var side: HandSide? = nil
    /// Vision didn't see this hand this frame: it is coasting through a short
    /// gap, at a position estimated from its recent movement. Fine to draw;
    /// never a reason to act.
    var isPredicted = false
    /// 1 while the hand is seen, falling toward 0 as a gap goes on.
    var trackingConfidence: CGFloat = 1

    /// Every detected joint of this hand as a flat list.
    var recognizedJoints: [CGPoint] { skeleton.flatMap { $0 } }

    /// Seen this frame and known to be the left or right hand — what any
    /// two-handed gesture needs before it may count.
    var isReliablyIdentified: Bool { !isPredicted && side != nil }
}
