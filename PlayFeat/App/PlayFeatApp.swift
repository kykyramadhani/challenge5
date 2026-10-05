//
//  PlayFeatApp.swift
//  PlayFeat
//

import SwiftUI
import SwiftData

@main
struct PlayFeatApp: App {
    init() {
        // Before any text is drawn: point the bundle at the language the
        // player last chose, so the app opens in it rather than flashing the
        // system language first.
        AppLocalization
            .applyStoredLanguage()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            app.debugScreenSize()
            #else
            app
            #endif
        }
    }

    private var app: some View {
        PhoneSafeSides {
            // Inside, not on the scene: PhoneSafeSides hosts the app
            // separately, and environment doesn't reach across.
            ContentView()
                .modelContainer(InventoryManager.shared.container)
        }
    }
}
