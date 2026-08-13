//
//  MainMenuView.swift
//  GetCooking
//

import SwiftUI

struct MainMenuView: View {
    let onPlay: () -> Void

    var body: some View {
        ZStack {
            Color.tertiary
                .ignoresSafeArea()

            VStack(spacing: 60) {
                Text("GetCooking")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(Color.text)

                ButtonComponent(
                    name: "Play",
                    icon: "play.fill",
                    action: onPlay,
                    buttonStyle: .primary
                )
            }
        }
    }
}

#Preview {
    MainMenuView(onPlay: {})
}
