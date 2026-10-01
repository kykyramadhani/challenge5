//
//  AppLanguage.swift
//  GetCooking
//
//  Created by Owen Limantoro on 22/08/26.
//

import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english
    case indonesia

    var id: String { rawValue }

    /// The `.lproj` this language's strings are compiled into — and so the
    /// code `AppLocalization` looks the bundle up by. These have to match the
    /// language identifiers in `Localizable.xcstrings`.
    var code: String {
        switch self {
        case .english: "en"
        case .indonesia: "id"
        }
    }

    /// Shown on the picker, in the language itself — a player looking for
    /// their own language should be able to recognise it without reading the
    /// one they cannot. Deliberately *not* translated for that reason.
    var displayName: LocalizedStringKey {
        switch self {
        case .english: "English"
        case .indonesia: "Indonesia"
        }
    }

    var locale: Locale { Locale(identifier: code) }
}
