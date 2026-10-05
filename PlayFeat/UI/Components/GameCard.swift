//
//  GameCard.swift
//  GetCooking
//
//  A single game tile in the main-menu carousel: cover art plus the
//  game's title, tappable to launch when the game is available.
//

import SwiftUI

struct GameCard: View {
    let game: GameOption
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            Image(game.imageName)
                .resizable()
                .scaledToFit()
                .overlay {
                    if !game.isAvailable {
                        Color.black.opacity(0.35)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 72, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .clipShape(
                    RoundedRectangle(cornerRadius: 80)
                )

            Text(game.title)
                .font(.atkinson(size: 64, weight: .bold))
                .foregroundStyle(.appPrimary)
        }
        .padding(24)
        .onTapGesture {
            // Only an available game is a real selection — a tap on a locked
            // card does nothing, so it shouldn't click either.
            if game.isAvailable {
                AudioManager.shared.play(.uiClick)
                onSelect()
            }
        }
    }
}

#Preview {
    ZStack {
        Color.white
        GameCard(game: .all[1], onSelect: {})
    }
}
