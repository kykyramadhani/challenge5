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

    @State private var coinCount = GameStorage.coins
    @State private var mostDishesServed = GameStorage.highscore

    @State private var showSettings = false

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
                    // The card already means "best run", so it doubles as the
                    // way into the Game Center leaderboard.
                    .onTapGesture { GameCenter.showLeaderboard() }

                // Tap-to-Play tray, centred low.
                playTray(w: w)
                    .position(x: w * 0.5, y: h * 0.77)

                // Shop — routes to Shop screen.
                ButtonComponent(
                    name: "Shop",
                    icon: "cart.fill",
                    action: sceneManager.goToShop,
                    buttonStyle: .text
                )
                .position(x: w * 0.85, y: h * 0.85)

                // Settings — the same control the old main menu carried; it
                // positions itself in the top-right corner.
                SettingsButton {
                    showSettings = true
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
        .onAppear {
            coinCount = GameStorage.coins
            mostDishesServed = GameStorage.highscore
        }
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

    /// The "Most Dishes Served" card. The cloche is baked into the asset; the
    /// label band is painted over in the same lime the art uses underneath it
    /// (measured off the source PNG), because the English label itself is
    /// baked into the pixels and cannot be translated any other way without a
    /// redrawn asset. The number is drawn fresh either way, into the black
    /// panel below.
    private func highscoreCard(w: CGFloat) -> some View {
        Image("HighscoreCard")
            .resizable()
            .scaledToFit()
            .frame(width: w * 0.16)
            .overlay {
                GeometryReader { g in
                    // Band position measured from HighscoreCard.png: it spans
                    // the full width, from 34% to 51% of the card's height.
                    Self.highscoreLabelColor
                        .frame(width: g.size.width, height: g.size.height * 0.170)
                        .position(x: g.size.width * 0.5, y: g.size.height * 0.425)

                    Text("Most Dishes Served")
                        .font(.system(size: g.size.height * 0.072, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .frame(width: g.size.width * 0.92)
                        .position(x: g.size.width * 0.5, y: g.size.height * 0.425)

                    Text(verbatim: "\(mostDishesServed)")
                        .font(.system(size: g.size.height * 0.22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .position(x: g.size.width * 0.5, y: g.size.height * 0.72)
                }
            }
    }

    /// Sampled from the lime band in HighscoreCard.png, so the painted-over
    /// label sits on a patch that matches the art around it exactly.
    private static let highscoreLabelColor = Color(red: 0.87, green: 1.0, blue: 0.10)
}

#Preview {
    GameOpening(sceneManager: SceneManager())
}
