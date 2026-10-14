//
//  PlayFeatApp.swift
//  PlayFeat
//

import SwiftUI
import SwiftData

@main
struct PlayFeatApp: App {
    @State private var audio = AudioManager()
    @State private var inventory = InventoryManager()
    @State private var camera: CameraManager
    @State private var handPoseManager: HandPoseManager

    @Environment(\.scenePhase) private var scenePhase

    init() {
        _camera = State(initialValue: CameraManager())
        _handPoseManager = State(initialValue: HandPoseManager())
        
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
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
    }

    private var app: some View {
        PhoneSafeSides {
            // Inside, not on the scene: PhoneSafeSides hosts the app
            // separately, and environment doesn't reach across. That includes
            // the scene phase, which GameplayView needs to pause the run.
            ContentView()
                .environment(audio)
                .environment(inventory)
                .environment(handPoseManager)
                .environment(\.scenePhase, scenePhase)
                .modelContainer(inventory.container)
        }
    }

    // MARK: - Leaving and returning to the foreground

    /// App-wide reaction; GameplayView pauses the run itself, since each run
    /// owns its own clock and scene.
    ///
    /// iOS always passes through `.inactive` on the way to `.background`, so
    /// the GPU stops there, while it is still allowed to finish a frame.
    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            handPoseManager.resume()
            audio.fadeInMusic()
        case .inactive:
            handPoseManager.suspend()
        case .background:
            handPoseManager.suspend()
            audio.fadeOutMusic()
        @unknown default:
            handPoseManager.suspend()
        }
    }
}
