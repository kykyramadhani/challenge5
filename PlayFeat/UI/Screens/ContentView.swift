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
    @State private var showSplashScreen = true

    /// False until the player has been through onboarding once. Backed by
    /// UserDefaults, so it survives launches but resets on a fresh install —
    /// exactly "show it only the first time the game is installed".
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(GameStorage.coinKey) private var coin: Int = 0
    @AppStorage(GameStorage.scoreKey) private var highscore: Int = 0

    /// Watched, not just stored: switching language has to redraw everything
    /// that has already been laid out, and views only rebuild for state they
    /// actually read.
    @AppStorage(AppLocalization.storageKey) private var language: AppLanguage = .english
    
    var body: some View {
        ZStack {
            currentScreen
                .tint(.appSecondaryText)

            // First-launch onboarding, above the menu but below the splash so
            // the splash still plays first. Dismissing it flips the flag, which
            // removes it for good.
            if !hasCompletedOnboarding {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        hasCompletedOnboarding = true
                    }
                }
                .transition(.opacity)
                .zIndex(50)
            }

            if showSplashScreen {
                SplashScreenView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    .zIndex(100)
            }

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
                hasCompletedOnboarding = true
                sceneManager.finishTutorial()
                sceneManager.play()
            }
            #endif

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showSplashScreen = false
                }
            }
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
