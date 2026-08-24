//
//  PlayFeatApp.swift
//  PlayFeat
//

import SwiftUI
import SwiftData

@main
struct PlayFeatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(InventoryManager.shared.container)
    }
}
