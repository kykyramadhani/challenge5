//
//  PlayFeatApp.swift
//  PlayFeat
//

import SwiftUI

@main
struct PlayFeatApp: App {
    init() {
        // Before any text is drawn: point the bundle at the language the
        // player last chose, so the app opens in it rather than flashing the
        // system language first.
        AppLocalization.applyStoredLanguage()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
