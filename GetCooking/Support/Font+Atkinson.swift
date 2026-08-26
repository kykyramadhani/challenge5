//
//  Font+Atkinson.swift
//  GetCooking
//
//  Every piece of text in the app is drawn in Atkinson Hyperlegible — a face
//  designed for low-vision readers, which is also just easier to read across a
//  room, which is how this game is played.
//

import SwiftUI

extension Font {
    /// `fixedSize:` rather than `size:` deliberately: the screens are laid out
    /// by hand as fractions of the frame, so text that grew with Dynamic Type
    /// would burst the cards it's positioned inside. This matches what the
    /// `.system(size:)` calls it replaced already did.
    static func atkinson(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(Atkinson.name(for: weight), fixedSize: size)
    }
}

/// The two faces that ship in the bundle, by PostScript name.
///
/// The family has no semibold/heavy/black, so everything from semibold up
/// collapses onto Bold — the call sites keep saying `.heavy` where they mean
/// "as loud as possible" and get the loudest weight that actually exists.
enum Atkinson {
    static let regular = "AtkinsonHyperlegible-Regular"
    static let bold = "AtkinsonHyperlegible-Bold"

    static func name(for weight: Font.Weight) -> String {
        switch weight {
        case .semibold, .bold, .heavy, .black: bold
        default: regular
        }
    }
}
