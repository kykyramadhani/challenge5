//
//  AppLocalization.swift
//  GetCooking
//
//  Makes the in-app language picker actually change the language.
//
//  Every localized lookup in the app — SwiftUI's `Text("…")` as much as
//  `String(localized:)` — resolves against `Bundle.main`, and that bundle
//  chooses its language *once*, from the system's language order. Writing
//  `AppleLanguages` into UserDefaults is the usual trick, but it only takes
//  effect on the next launch, and a settings toggle that needs the app
//  restarted is not a working settings toggle.
//
//  So `Bundle.main` is given a subclass that forwards every lookup to the
//  chosen `.lproj` bundle instead. Every existing call site keeps working
//  untouched and picks up the new language the moment it is chosen.
//

import Foundation
import SwiftUI

enum AppLocalization {

    /// UserDefaults key the picker writes to. Shared with `SettingsView`'s
    /// `@AppStorage`, so the two can never drift apart.
    static let storageKey = "settings.language"

    /// The language currently in force.
    static var current: AppLanguage {
        UserDefaults.standard.string(forKey: storageKey)
            .flatMap(AppLanguage.init(rawValue:))
            ?? .english
    }

    /// Points `Bundle.main` at `language`'s strings.
    ///
    /// Safe to call repeatedly; the class swap only happens once.
    static func apply(_ language: AppLanguage) {
        if !(Bundle.main is LocalizedBundle) {
            object_setClass(Bundle.main, LocalizedBundle.self)
        }
        Bundle.overrideLocalization = localizedBundle(for: language)
    }

    /// Re-applies whatever was stored last. Call once at launch, before any
    /// text has been drawn.
    static func applyStoredLanguage() {
        apply(current)
    }

    /// Resolves a catalog string in the selected language.
    ///
    /// `Text("…")` goes through the bundle swap above on its own, but
    /// `String(localized:)` is worth routing through here explicitly so a
    /// caller reading copy *outside* a view — `TutorialPage`, say — cannot
    /// end up with the system language by accident.
    static func string(_ value: String.LocalizationValue) -> String {
        String(localized: value, bundle: Bundle.overrideLocalization ?? .main)
    }

    private static func localizedBundle(for language: AppLanguage) -> Bundle? {
        guard let path = Bundle.main.path(forResource: language.code, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            // No compiled strings for that language — fall back to the base
            // localization rather than showing raw keys.
            return nil
        }
        return bundle
    }
}

// MARK: - The swapped-in bundle

/// `Bundle.main` wearing this class forwards its string lookups to whichever
/// `.lproj` the player picked.
private final class LocalizedBundle: Bundle, @unchecked Sendable {
    override func localizedString(
        forKey key: String,
        value: String?,
        table tableName: String?
    ) -> String {
        guard let override = Bundle.overrideLocalization else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return override.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    /// The `.lproj` every lookup is redirected to, or nil for the base
    /// localization. Stored here rather than on `LocalizedBundle` because the
    /// instance being swapped is `Bundle.main` itself, which we do not own.
    fileprivate(set) static var overrideLocalization: Bundle? {
        get { objc_getAssociatedObject(Bundle.main, &overrideKey) as? Bundle }
        set {
            objc_setAssociatedObject(
                Bundle.main, &overrideKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

private nonisolated(unsafe) var overrideKey: UInt8 = 0
