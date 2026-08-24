//
//  HandSide.swift
//  GetCooking
//
//  Which hand one-hand mode asks the player to calibrate with.
//

import SwiftUI

enum HandSide: String, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }

    /// Shown on the settings picker.
    ///
    /// A `LocalizedStringKey`, not a `String`: SwiftUI only looks a string up
    /// in the catalog when it arrives as a key. Handing `Text` a plain `String`
    /// renders it verbatim, which is exactly how these stayed in English while
    /// everything around them translated.
    var displayName: LocalizedStringKey {
        switch self {
        case .left: "Left Hand"
        case .right: "Right Hand"
        }
    }

    /// The same label as a resolved string, for the few places that need one
    /// outside a view — the seat check builds its instruction by interpolation.
    var localizedName: String {
        switch self {
        case .left: String(localized: "Left Hand", bundle: Bundle.overrideLocalization ?? .main)
        case .right: String(localized: "Right Hand", bundle: Bundle.overrideLocalization ?? .main)
        }
    }
}
