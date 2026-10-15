//
//  ContentView.swift
//  PlayFeat
//
//  Root view: shows whichever AppScreen SceneManager is on, with onboarding
//  and the splash layered above it.
//
//  A plain switch rather than a NavigationStack: every screen is full-screen
//  with no back button, and each exit jumps to a known screen, so there is no
//  stack to keep. GameStateManager stays inside GameplayView, so every run
//  starts fresh.
//

import SwiftUI

struct ContentView: View {
    @Environment(InventoryManager.self) private var inventory
    @Environment(HandPoseManager.self) private var handPoseManager
    @Environment(AudioManager.self) private var audio
    
    @State private var sceneManager = SceneManager()
    @AppStorage(GameStorage.coinKey) private var coin: Int = 0
    @AppStorage(GameStorage.scoreKey) private var highscore: Int = 0

    /// Watched, not just stored: switching language has to redraw everything
    /// that has already been laid out, and views only rebuild for state they
    /// actually read.
    @AppStorage(AppLocalization.storageKey) private var language: AppLanguage = .english
    
    var body: some View {
        ZStack {
            // The space-kitchen title screen is the launch screen now; the
            // old splash and Smoove onboarding are no longer shown.
            currentScreen
                .tint(.appSecondaryText)
        }
        // Inside the language handling below, so the prompt follows the
        // in-game language like every other piece of text.
        .requiresLandscape()
        // Rebuilds the whole tree when the language changes. Redirecting the
        // bundle is not enough on its own: views already on screen keep the
        // text they resolved when they were built, so they have to be thrown
        // away and made again.
        .id(language)
        .environment(\.locale, language.locale)
        .onAppear {
            // Here rather than in the App's init: GameKit's sign-in screen
            // needs a window to be presented from, and there isn't one yet
            // when the App value is built.
            GameCenter.authenticate()

            #if DEBUG
            DebugLaunch.applyLandscapeIfRequested()
            if DebugLaunch.skipToGameplay {
                sceneManager.play(DebugLaunch.role)
            }
            #endif
        }
        .onChange(of: language) { _, newValue in
            AppLocalization.apply(newValue)
        }
        .animation(.easeInOut(duration: 0.3), value: sceneManager.screen)
    }

    /// The camera preview lives inside GameplayView, as that screen's
    /// backmost layer. The capture *session* is owned by HandPoseManager, so
    /// mounting the preview there doesn't rebuild the pipeline.
    @ViewBuilder
    private var currentScreen: some View {
        switch sceneManager.screen {
        case .title:
            TitleScreenView { sceneManager.goToRoleSelect() }
                .transition(.opacity)
        case .roleSelect:
            RoleSelectView { sceneManager.play($0) }
                .transition(.opacity)
        case .procurement:
            ProcurementView(sceneManager: sceneManager, handPoseManager: handPoseManager, audio: audio)
                .transition(.opacity)
        case .chef:
            ChefView(sceneManager: sceneManager, handPoseManager: handPoseManager, audio: audio)
                .transition(.opacity)
        case .mainMenu:
            GameOpening(sceneManager: sceneManager)
                .transition(.opacity)
        case .shop:
            ShopView(sceneManager: sceneManager)
                .transition(.opacity)
        case .gameplay:
            GameplayView(
                sceneManager: sceneManager,
                handPoseManager: handPoseManager,
                inventory: inventory,
                audio: audio
            )
            .transition(.opacity)
        case .postGame(let result):
            PostGameView(result: result, sceneManager: sceneManager)
                .transition(.opacity)
        }
    }
}

#Preview {
    ContentView()
        .environment(InventoryManager(inMemory: true))
        .environment(HandPoseManager())
        .environment(AudioManager())
}
