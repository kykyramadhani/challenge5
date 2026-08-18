//
//  GameOpeningView.swift
//  GetCooking
//
//  Created by Owen Limantoro on 15/08/26.
//

import SwiftUI

struct GameOpening: View {
    var game: GameOption
    
    @Bindable var sceneManager: SceneManager

    var body: some View {
        ZStack {
            BackgroundImage(game.imageName)

            VStack {
                // Your foreground content
                VStack(spacing: 42) {
                    Text(game.title)
                        .font(.system(size: 128, weight: .bold))
                        .foregroundStyle(.appPrimary)

                    Divider()
                        .frame(height: 3)
                        .background(.appText)

                    if let score = game.highScore {
                        Text("Your High Score: \(score.formatted())")
                            .font(.system(size: 42, weight: .bold))
                    }
                }
                .frame(width: 700)

                ButtonComponent(
                    name: "Play Button",
                    icon: "play.fill",
                    action: {
                        sceneManager.goToGameplay()
                    },
                    buttonStyle: .primary
                )
            }

            BackButton {
                sceneManager.goToMainMenu()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    GameOpening(game: GameOption.all[0], sceneManager: SceneManager())
}
