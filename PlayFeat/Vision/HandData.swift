//
//  SwiftUIView.swift
//  GetCooking
//
//  Created by Owen Limantoro on 12/08/26.
//

import SwiftUI

/// One tracked hand, as published to the UI and the scene.
///
/// `id` is stable across frames — see `matchToTrackedHands`. Without that,
/// two-handed play breaks the moment Vision reorders its observations, because
/// each hand would inherit the other's grab.
struct HandData: Identifiable, Equatable {
    let id: Int
    /// Palm centre in *normalized Vision space* (origin bottom-left, 0...1).
    var cursorPosition: CGPoint
    /// Not grabbing. Anything that isn't an active thumb-to-little-finger
    /// pinch is open, a clenched fist included.
    var isOpenHand: Bool
    /// Grabbing: thumb tip and little-finger tip pinched together.
    var isClosedFist: Bool
    /// One chain of joints per finger (thumb → little), normalized Vision space.
    var skeleton: [[CGPoint]]

    /// Every detected joint of this hand as a flat list.
    var recognizedJoints: [CGPoint] { skeleton.flatMap { $0 } }
}
