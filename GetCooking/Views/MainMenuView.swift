//
//  MainMenuView.swift
//  GetCooking
//
//  A horizontal carousel of selectable games. The centered card is
//  full size; neighbours shrink and fade. Scrolling snaps one card
//  at a time (viewAligned), so exactly one game is ever the focus.
//

import SwiftUI

struct MainMenuView: View {
    @Bindable var sceneManager: SceneManager
    @State private var showSettings = false

    private let games = GameOption.all
    var body: some View {
        ZStack {
            Color.menuBG
                .ignoresSafeArea()

            GeometryReader { proxy in
                let cardWidth = proxy.size.width * 0.65
                let sidePadding = (proxy.size.width - cardWidth) / 2

                ScrollView(.horizontal) {
                    LazyHStack(spacing: -50){
                        ForEach(games) { game in
                            GameCard(game: game) {
                                if game.isAvailable {
                                    sceneManager.startGame(game: game)
                                }
                            }
                            .frame(width: cardWidth)
                            .scrollTransition(.interactive, axis: .horizontal) {
                                content,
                                phase in
                                content
                                    .scaleEffect(
                                        x: phase.isIdentity ? 1 : 0.75,
                                        y: phase.isIdentity ? 1 : 0.75
                                    )
                                    .opacity(phase.isIdentity ? 1 : 0.7)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                .safeAreaPadding(.horizontal, sidePadding)
                .frame(maxHeight: .infinity, alignment: .center)
            }
            
            SettingsButton {
                showSettings = true
            }

            // A dimmed card over the menu rather than a system sheet, so it
            // carries the game's own styling (see SettingsView).
            if showSettings {
                SettingsView(onClose: { showSettings = false })
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSettings)
    }
}

#Preview {
    MainMenuView(sceneManager: SceneManager.init())
}
