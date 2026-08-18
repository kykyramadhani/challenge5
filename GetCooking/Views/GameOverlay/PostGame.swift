//
//  PostGame.swift
//  GetCooking
//
//  Created by Owen Limantoro on 13/08/26.
//

import SwiftUI

struct PostGame: View {
    var score: Int
    var survivedSeconds: Int
    var onRestart: () -> Void
    
    var sceneManager: SceneManager

    var body: some View {
        ZStack {
            if let imageName = sceneManager.selectedGame?.imageName {
                BackgroundImage(imageName)
            }

            VStack(spacing: .zero) {
                HStack {
                    VStack {
                        Text(score.formatted(.number))
                            .font(.system(size: 128, weight: .bold))

                        Text("SCORE")
                            .font(.system(size: 40, weight: .medium))
                    }

                    Divider()
                        .frame(width: 3)
                        .background(.appText)
                        .padding(100)

                    VStack {
                        Text("SURVIVED")
                            .font(.system(size: 40, weight: .medium))

                        Text(
                            Duration.seconds(survivedSeconds)
                                .formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2)))
                        )
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
                        action: sceneManager.goToMainMenu,
                        buttonStyle: .text
                    )
                }
            }
        }
    }
}

#Preview {
    PostGame(score: 1000, survivedSeconds: 166, onRestart: {}, sceneManager: SceneManager.init())
}
