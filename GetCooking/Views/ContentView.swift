//
//  ContentView.swift
//  VisionChef
//
//  Root view that switches between the main menu and gameplay. SceneManager
//  owns which screen is showing.
//
//  Both HandPoseManager *and* the camera preview live here rather than
//  inside a screen. The seat check and the game each need the camera, and
//  building either one per screen means tearing the capture pipeline down
//  and standing it back up mid-flow — a stall right as the countdown is
//  meant to start.
//
//  The seat check no longer has its own navigation destination. GameplayView
//  runs it as its first phase and then swaps itself into the game, so there is
//  exactly one "gameplay" destination and nothing gets swapped underneath the
//  NavigationStack mid-flow. GameStateManager stays inside GameplayView, so
//  every run starts fresh.
//

import Combine
import SwiftUI

struct ContentView: View {
    @State private var sceneManager = SceneManager()
    @StateObject private var handPoseManager = HandPoseManager()
    @State private var showSplashScreen = true

    /// False until the player has been through onboarding once. Backed by
    /// UserDefaults, so it survives launches but resets on a fresh install —
    /// exactly "show it only the first time the game is installed".
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("coin") private var coin: Int = 0
    @AppStorage("highscore") private var highscore: Int = 0

    /// Watched, not just stored: switching language has to redraw everything
    /// that has already been laid out, and views only rebuild for state they
    /// actually read.
    @AppStorage(AppLocalization.storageKey) private var language: AppLanguage = .english

    var body: some View {
        ZStack {
            // The camera preview lives inside GameplayView — the only screen that
            // shows it — mounted as that screen's backmost layer so it sits behind
            // both the seat check and the board. It can't live here behind the
            // NavigationStack: a transparent top screen reveals the screen *beneath
            // it in the stack* (the opaque menu / game-opening), not a sibling drawn
            // behind the whole stack, so a camera here is always occluded. The
            // capture *session* is still owned by HandPoseManager, so hosting the
            // preview view downstream doesn't rebuild the pipeline.
            NavigationStack(path: $sceneManager.path) {
                // The opening screen is the root now — the old MainMenuView
                // carousel is retired, so the splash lands straight here.
                GameOpening(sceneManager: sceneManager)
                    .navigationDestination(for: String.self) { destination in
                        if destination == "gameplay" {
                            GameplayView(
                                sceneManager: sceneManager,
                                handPoseManager: handPoseManager
                            )
                        }
                    }
                    .navigationDestination(for: GameResult.self) { result in
                        PostGameView(result: result, sceneManager: sceneManager)
                    }
            }
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
        // Rebuilds the whole tree when the language changes. Redirecting the
        // bundle is not enough on its own: views already on screen keep the
        // text they resolved when they were built, so they have to be thrown
        // away and made again.
        .id(language)
        .environment(\.locale, language.locale)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showSplashScreen = false
                }
            }
        }
        .onChange(of: language) { _, newValue in
            AppLocalization.apply(newValue)
        }
    }
}

#Preview {
    ContentView()
}
