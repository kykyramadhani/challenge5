//
//  PostGame.swift
//  GetCooking
//
//  Created by Owen Limantoro on 13/08/26.
//

import SwiftUI

struct PostGame: View {
    var score: Int
    var onRestart: () -> Void
    var onMainMenu: () -> Void

    var body: some View {
        ZStack {
            Color.tertiary
                .ignoresSafeArea()

            VStack(spacing: .zero) {
                HStack {
                    VStack {
                        Text(score.formatted())
                            .font(.system(size: 128, weight: .bold))

                        Text("SCORE")
                            .font(.system(size: 40, weight: .medium))
                    }

                    Divider()
                        .frame(width: 3)
                        .background(.text)
                        .padding(100)

                    VStack {
                        Text("SURVIVED")
                            .font(.system(size: 40, weight: .medium))

                        Text("02:46")
                            .font(.system(size: 128, weight: .bold))
                    }
                }
                .frame(height: 500)

                HStack(spacing: 40) {
                    ButtonComponent(
                        name: "Play Again",
                        icon: "play.fill",
                        action: onRestart,
                        buttonStyle: .primary
                    )

                    ButtonComponent(
                        name: "Main Menu",
                        icon: "house.fill",
                        action: onMainMenu,
                        buttonStyle: .text
                    )
                }
            }
        }
    }
}

#Preview {
    PostGame(score: 1000, onRestart: {}, onMainMenu: {})
}
