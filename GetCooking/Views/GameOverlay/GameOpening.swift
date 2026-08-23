//
//  GameOpeningView.swift
//  GetCooking
//
//  The app's start screen — shown straight after the splash. The old
//  MainMenuView carousel is retired: there is a single game now, so this
//  screen *is* the menu. "Tap to Play" drops straight into the run.
//
//  Everything is laid out with a GeometryReader and `.position`, as fractions
//  of the screen, so the same arrangement holds from iPhone to iPad Pro.
//

import SwiftUI

struct GameOpening: View {
    @Bindable var sceneManager: SceneManager

    // Placeholder values for now — these get wired to the AppStorage-saved
    // game session later, so they read live from the player's best run.
    private let coinCount = GameStorage.coins
    private let mostDishesServed = GameStorage.highscore

    @State private var showSettings = false
    @State private var showShopComingSoon = false

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                // Full-bleed kitchen backdrop.
                Image("MainMenuBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: w, height: h)
                    .clipped()

                // "Play Feat!" logo, centred in the upper third.
                Image("Title")
                    .resizable()
                    .scaledToFit()
                    .frame(width: w * 0.52)
                    .position(x: w * 0.5, y: h * 0.33)

                // Mascot peeking in from the left edge.
                Image("Happy")
                    .resizable()
                    .scaledToFit()
                    .frame(width: w * 0.3)
                    .rotationEffect(.degrees(50), anchor: .leading)
                    .position(x: w * 0.15, y: h * 0.3)

                // Coin balance, top-left.
                coinPill(h: h)
                    .position(x: w * 0.14, y: h * 0.12)

                // Most-dishes-served card, bottom-left.
                highscoreCard(w: w)
                    .position(x: w * 0.125, y: h * 0.82)

                // Tap-to-Play tray, centred low.
                playTray(w: w)
                    .position(x: w * 0.5, y: h * 0.77)

                // Shop — the same button the results screen uses, kept enabled.
                ButtonComponent(
                    name: "Shop",
                    icon: "cart.fill",
                    action: { withAnimation(.easeInOut(duration: 0.2)) { showShopComingSoon = true } },
                    buttonStyle: .text
                )
                .position(x: w * 0.85, y: h * 0.85)

                // Settings — the same control the old main menu carried; it
                // positions itself in the top-right corner.
                SettingsButton {
                    showSettings = true
                }

                // Overlays, above everything.
                if showShopComingSoon {
                    ShopComingSoonPopup {
                        withAnimation(.easeInOut(duration: 0.2)) { showShopComingSoon = false }
                    }
                    .transition(.opacity)
                    .zIndex(2)
                }

                if showSettings {
                    SettingsView(onClose: { showSettings = false })
                        .transition(.opacity)
                        .zIndex(3)
                }
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeInOut(duration: 0.2), value: showSettings)
    }

    // MARK: - Pieces

    /// White pill holding the coin icon and the balance.
    private func coinPill(h: CGFloat) -> some View {
        HStack(spacing: h * 0.014) {
            Image("Coin")
                .resizable()
                .scaledToFit()
                .frame(width: h * 0.06, height: h * 0.06)

            Text("\(coinCount)")
                .font(.system(size: h * 0.05, weight: .heavy, design: .rounded))
                .foregroundStyle(.black)
        }
        .padding(.horizontal, h * 0.028)
        .padding(.vertical, h * 0.012)
        .background(
            Capsule()
                .fill(.white)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        )
    }

    /// The orange tray with its plate, captioned "Tap to Play". The whole tray
    /// is the tap target — reaching it starts the run.
    private func playTray(w: CGFloat) -> some View {
        Image("TrayPlate")
            .resizable()
            .scaledToFit()
            .frame(width: w * 0.38)
            .overlay {
                GeometryReader { g in
                    VStack(spacing: g.size.height * 0.03) {
                        Image(systemName: "play.fill")
                            .font(.system(size: g.size.height * 0.16, weight: .bold))
                        
                        Text("Tap to Play")
                            .font(.system(size: g.size.height * 0.1, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.black)
                    // The plate sits a touch above the tray's centre.
                    .position(x: g.size.width * 0.5, y: g.size.height * 0.44)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                AudioManager.shared.play(.uiClick)
                sceneManager.play(GameOption.all[0])
            }
    }

    /// The "Most Dishes Served" card. The label and cloche are baked into the
    /// asset; only the number is drawn, into the black panel below the label.
    private func highscoreCard(w: CGFloat) -> some View {
        Image("HighscoreCard")
            .resizable()
            .scaledToFit()
            .frame(width: w * 0.16)
            .overlay {
                GeometryReader { g in
                    Text("\(mostDishesServed)")
                        .font(.system(size: g.size.height * 0.22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .position(x: g.size.width * 0.5, y: g.size.height * 0.72)
                }
            }
    }
}

#Preview {
    GameOpening(sceneManager: SceneManager())
}
