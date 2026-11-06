//
//  LocalizationTests.swift
//  PlayFeatTests
//
//  Split out of GetCookingTests.swift (created by Kyky on 11/08/26).
//

import Testing
import Foundation
import CoreGraphics
import SwiftUI
@testable import PlayFeat

/// The in-app language picker. Writing the preference is not enough on its
/// own — something has to point the bundle at the chosen strings, which is
/// the bug this suite exists to catch.
@MainActor
struct LocalizationTests {

    /// Every language the picker offers has to have strings compiled into the
    /// app. A missing `.lproj` is why a picker silently does nothing.
    @Test func everyOfferedLanguageIsBuiltIntoTheApp() {
        for language in AppLanguage.allCases {
            // English is the development language and lives in the base
            // localization, so it has no separate .lproj to find.
            guard language != .english else { continue }

            #expect(
                Bundle.main.path(forResource: language.code, ofType: "lproj") != nil,
                "no compiled strings for \(language.code) — the picker cannot switch to it"
            )
        }
    }

    /// `CFBundleLocalizations` is what the system reads when it decides which
    /// language to launch the app in, so it has to list real language
    /// identifiers — the same ones the `.lproj` folders are named after. It
    /// shipped once saying "indonesia", which is the enum case's name and
    /// matches nothing.
    @Test func declaredLocalizationsUseRealLanguageCodes() throws {
        let declared = try #require(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleLocalizations") as? [String]
        )

        for language in AppLanguage.allCases {
            #expect(declared.contains(language.code),
                    "Info.plist does not declare \(language.code)")
        }
    }

    /// The actual switch: after applying Indonesian, a known catalog string
    /// has to come back translated rather than in English.
    @Test func applyingALanguageChangesWhatStringsResolveTo() {
        let key: String.LocalizationValue = "All set! Delivered lots of dishes and stay active!"
        defer { AppLocalization.apply(.english) }

        AppLocalization.apply(.indonesia)
        let indonesian = AppLocalization.string(key)

        AppLocalization.apply(.english)
        let english = AppLocalization.string(key)

        #expect(indonesian != english, "the bundle redirect is not taking effect")
        #expect(indonesian == "Semuanya siap! Sajikan banyak hidangan dan tetaplah aktif!")
    }

    /// The tutorial reads its copy outside the view tree, so it has to follow
    /// the picker too — this is the path that would otherwise stay English.
    @Test func tutorialCopyFollowsTheChosenLanguage() throws {
        defer { AppLocalization.apply(.english) }
        let page = try #require(TutorialPage.all.first { $0.id == "11" })

        AppLocalization.apply(.indonesia)
        let indonesian = try #require(page.localizedMessage)

        AppLocalization.apply(.english)
        let english = try #require(page.localizedMessage)

        #expect(indonesian != english)
    }

    /// Every screen the player reported as still-English: the settings
    /// sheet, the seat check, and the post-game paycheck and buttons. Each of
    /// these keys existed in the catalog (Xcode's extractor found the
    /// literal) but had never actually been given an Indonesian value — the
    /// bundle redirect had nothing to redirect *to*, so it silently fell back
    /// to the English source text. This is the regression test for that: a
    /// key present but untranslated is exactly as broken as a key that is
    /// missing outright, and this fails either way.
    @Test func everyUserFacingScreenHasIndonesianTranslations() {
        let keys: [String.LocalizationValue] = [
            // Settings sheet
            "Music", "Sound Effects", "Language", "One-hand Mode", "OFF", "ON",
            "Left Hand", "Right Hand",
            // Seat check
            "Adjust your seat to fit in the frame",
            "Adjust your seat and raise your left hand",
            "Adjust your seat and raise your right hand",
            // Post-game paycheck and buttons
            "Speed Bonus", "Dishes Served", "Play Again", "Shop", "Main Menu",
            // Main menu
            "Most Dishes Served",
        ]

        defer { AppLocalization.apply(.english) }
        AppLocalization.apply(.indonesia)

        for key in keys {
            let indonesian = AppLocalization.string(key)
            let english = String(localized: key)
            #expect(indonesian != english, "\"\(english)\" has no Indonesian translation")
        }
    }
}
