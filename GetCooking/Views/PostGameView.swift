//
//  PostGame.swift
//  GetCooking
//
//  The end-of-run summary: the paycheck (dishes served + speed bonus + total)
//  and a per-dish-type tally, driven by the run's GameStateManager.
//

import SwiftUI

/// A value snapshot of a finished run, passed to the results screen so it needs
/// no live reference to the GameStateManager that produced it.
struct GameResult: Hashable {
    private let dishCost = 10
    
    var dishesByType: [String: Int]
    var speedBonus: Int
    var hasMultiplier: Bool = false

    /// Every dish completed this run, all kinds summed.
    var totalDishesServed: Int { dishesByType.values.reduce(0, +) }
    var dishesEarnings: Int { totalDishesServed * dishCost }
    var baseCoins: Int { dishesEarnings + speedBonus }
    var totalCoins: Int {
        hasMultiplier ? baseCoins * 2 : baseCoins
    }
    
    var newHighScore: Bool {
        GameStorage.highscore < totalDishesServed
    }
}

struct PostGameView: View {
    let result: GameResult
    var sceneManager: SceneManager

    /// The four dish types shown in the tally, paired with the asset name each
    /// uses for its plate art. The key matches a recipe's `finishedDishImageName`,
    /// which is how GameStateManager counts them.
    private let dishTypes: [(key: String, image: String)] = [
        ("salad", "salad"),
        ("ChickenMayonnaise", "ChickenMayonnaise"),
        ("ChickenGeprek", "ChickenGeprek"),
        ("ChickenMozarella", "ChickenMozarella"),
    ]

    /// Drives the staggered entrance. Flipped true on appear; each section
    /// reads it through `RevealOnAppear` with its own delay, so the paycheck,
    /// the dish tally and the buttons fade up one after another.
    @State private var revealed = false

    var body: some View {
        ZStack {
            if let imageName = sceneManager.selectedGame?.imageName {
                BackgroundImage(imageName)
            }

            VStack(spacing: 80) {
                VStack(spacing: 32) {
                    PayCheckView(
                        result: result
                    )
                    .modifier(RevealOnAppear(revealed: revealed, delay: 0.1))

                    HStack(spacing: 35) {
                        ForEach(dishTypes, id: \.key) { dish in
                            foodPlate(
                                food: dish.image,
                                width: 150,
                                height: 150,
                                dishServed: result.dishesByType[dish.key] ?? 0
                            )
                        }
                    }
                    .modifier(RevealOnAppear(revealed: revealed, delay: 0.3))
                }

                HStack(spacing: 40) {
                    ButtonComponent(
                        name: "Play Again",
                        icon: "play.fill",
                        action: sceneManager.replayGame,
                        buttonStyle: .primary
                    )

                    ButtonComponent(
                        name: "Shop",
                        icon: "cart.fill",
                        action: sceneManager.goToShop,
                        buttonStyle: .text
                    )

                    ButtonComponent(
                        name: "Main Menu",
                        icon: "square.grid.2x2.fill",
                        action: sceneManager.goToMainMenu,
                        buttonStyle: .text
                    )
                }
                .modifier(RevealOnAppear(revealed: revealed, delay: 0.5))
                // Nothing to tap until the buttons have actually arrived.
                .allowsHitTesting(revealed)
            }
            .onAppear { revealed = true }
        }
        // Its own screen now — no system back chrome.
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Fades and lifts a section into place once `revealed` turns true, after its
/// own `delay`. Off-screen it starts slightly lower and transparent, so the
/// results settle in from the bottom one row at a time.
private struct RevealOnAppear: ViewModifier {
    let revealed: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 24)
            .animation(.easeOut(duration: 0.5).delay(delay), value: revealed)
    }
}

struct foodPlate: View {
    let food: String
    let width: CGFloat
    let height: CGFloat
    let dishServed: Int

    var body: some View {
        ZStack {
            Image("plate")
                .resizable()
                .frame(width: width, height: height)

            Image(food)
                .resizable()
                .frame(width: width * 0.7, height: height * 0.7)

            Text("x\(dishServed)")
                .font(.custom(size: 40, weight: .bold))
                .foregroundColor(.appPrimary)
                .offset(x: width * 0.5, y: height * 0.4)
        }
    }
}

#Preview {
    PostGameView(
        result: GameResult(
            dishesByType: ["salad": 4, "ChickenMayonnaise": 4, "ChickenGeprek": 3, "ChickenMozarella": 2],
            speedBonus: 20
        ),
        sceneManager: SceneManager()
    )
}
