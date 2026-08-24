//
//  ShopView.swift
//  GetCooking
//
//  The Shop screen where players can purchase power-ups and multipliers.
//

import SwiftUI

struct ShopView: View {
    @Bindable var sceneManager: SceneManager
    @ObservedObject private var inventoryManager = InventoryManager.shared

    @State private var coinCount: Int = GameStorage.coins
    @State private var items: [ShopItem] = ShopItem.all
    @State private var showNotEnoughCoinsAlert = false

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 340), spacing: 32)
    ]

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                // Full-bleed kitchen backdrop matching main menu
                Image("MainMenuBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: w, height: h)
                    .clipped()

                // Top bar: Back button on the left, Coin Pill on the right
                BackButton {
                    sceneManager.goToMainMenu()
                }

                // Coin pill in top-right
                coinPill(h: h)
                    .position(x: w * 0.86, y: h * 0.1)

                // Main content
                VStack(spacing: h * 0.04) {
                    // Screen Title "Shops" in the middle
                    Text("Shops")
                        .font(.system(size: h * 0.09, weight: .heavy, design: .rounded))
                        .foregroundStyle(.appTertiaryText)
                        .padding(.top, h * 0.06)

                    // Grid of purchasable items
                    LazyVGrid(columns: columns, spacing: 32) {
                        ForEach(items) { item in
                            shopItemCard(item: item, w: w, h: h)
                        }
                    }
                    .padding(.horizontal, w * 0.1)

                    Spacer()
                }
                .frame(width: w, height: h)

                // Not enough coins toast / banner if triggered
                if showNotEnoughCoinsAlert {
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text("Not enough coins!")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.85))
                                .shadow(radius: 10)
                        )
                        .padding(.bottom, h * 0.1)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .zIndex(10)
                }
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            coinCount = GameStorage.coins
            inventoryManager.refresh()
        }
    }

    // MARK: - Components

    /// White pill holding the coin icon and current balance
    private func coinPill(h: CGFloat) -> some View {
        HStack(spacing: h * 0.014) {
            Image("Coin")
                .resizable()
                .scaledToFit()
                .frame(width: h * 0.055, height: h * 0.055)

            Text("\(coinCount)")
                .font(.system(size: h * 0.045, weight: .heavy, design: .rounded))
                .foregroundStyle(.black)
        }
        .padding(.horizontal, h * 0.024)
        .padding(.vertical, h * 0.01)
        .background(
            Capsule()
                .fill(.white)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
    }

    /// Single item card in the shop grid with drop shadow
    private func shopItemCard(item: ShopItem, w: CGFloat, h: CGFloat) -> some View {
        let cardWidth: CGFloat = min(w * 0.32, 340)
        let canAfford = coinCount >= item.price

        return VStack(spacing: 16) {
            // Owned badge
            HStack {
                Spacer()
                Text("Owned: \(inventoryManager.coinMultipliers)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.appTertiaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.appBackground.opacity(0.35))
                    )
            }

            // Multiplier Graphic
            coinMultiplier(width: cardWidth * 0.45, height: cardWidth * 0.45)
                .padding(.vertical, 8)

            // Item Title
            Text(item.name)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.black)

            // Item Description
            Text(item.description)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .frame(height: 44)
                .padding(.horizontal, 8)

            // Buy Button
            Button(action: {
                buyItem(item)
            }) {
                HStack(spacing: 8) {
                    Image("Coin")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)

                    Text("\(item.price)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Buy")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(canAfford ? Color.appPrimary : Color.gray.opacity(0.6))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(width: cardWidth)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
        )
    }

    // MARK: - Actions

    private func buyItem(_ item: ShopItem) {
        if coinCount >= item.price {
            AudioManager.shared.play(.addPoint)
            GameStorage.coins -= item.price
            coinCount = GameStorage.coins
            inventoryManager.addMultipliers(1)
        } else {
            AudioManager.shared.play(.loseHeart)
            withAnimation(.easeInOut(duration: 0.25)) {
                showNotEnoughCoinsAlert = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showNotEnoughCoinsAlert = false
                }
            }
        }
    }
}

#Preview {
    ShopView(sceneManager: SceneManager())
}
