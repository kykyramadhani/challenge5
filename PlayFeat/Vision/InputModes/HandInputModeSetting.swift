//
//  HandInputModeSetting.swift
//  PlayFeat
//
//  Turns the Settings values into the `HandInputMode` they describe — the only
//  place that knows how that setting is stored.
//

import Foundation

/// `nonisolated`: the camera's video queue reads the mode every frame.
nonisolated enum HandInputModeSetting {
    /// UserDefaults keys, shared with the `@AppStorage` properties that edit
    /// and read them, so the two can never drift apart.
    static let isOneHandKey = "oneHandModeEnabled"
    static let preferredHandKey = "preferredHand"

    static func mode(isOneHand: Bool, preferredHand: HandSide) -> any HandInputMode {
        isOneHand ? OneHandMode(hand: preferredHand) : TwoHandMode()
    }

    /// The mode the player last chose. Read straight from UserDefaults, so it
    /// works off the main thread — the Vision queue asks for it every frame,
    /// which is also what lets a change in Settings apply immediately.
    static func stored(in defaults: UserDefaults = .standard) -> any HandInputMode {
        let preferredHand = defaults.string(forKey: preferredHandKey).flatMap(HandSide.init) ?? .right
        return mode(isOneHand: defaults.bool(forKey: isOneHandKey), preferredHand: preferredHand)
    }
}
