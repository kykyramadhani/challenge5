//
//  RoleSelectView.swift
//  PlayFeat
//
//  "Choose your role": Procurement, Chef or Front House. The roles the player
//  doesn't pick are run by the kitchen crew. Only Procurement can be played
//  yet; the other two say so instead of starting a game that isn't there.
//

import SwiftUI

struct RoleSelectView: View {
    var onPlay: (KitchenRole) -> Void

    @State private var comingSoon = false

    var body: some View {
        ZStack {
            Image("SpaceBackground")
                .resizable()
                .scaledToFill()
                .overlay(Color.black.opacity(0.35))
                .ignoresSafeArea()

            VStack(spacing: 55) {
                Text("CHOOSE YOUR ROLE")
                    .font(.atkinson(size: 62, weight: .black))
                    .foregroundStyle(.kitchenElevated)

                HStack(spacing: 24) {
                    ForEach(KitchenRole.allCases) { role in
                        RoleCard(role: role) { choose(role) }
                    }
                }
            }
            .designScaled()

            if comingSoon {
                ShopComingSoonPopup(
                    title: "Coming Soon!",
                    message: "Front-House isn't open yet. It's being run by the crew for now.",
                    onClose: { comingSoon = false }
                )
                .designScaled()
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: comingSoon)
    }

    private func choose(_ role: KitchenRole) {
        if role.isPlayable {
            onPlay(role)
        } else {
            comingSoon = true
        }
    }
}

#Preview {
    RoleSelectView(onPlay: { _ in })
        .environment(AudioManager())
}
