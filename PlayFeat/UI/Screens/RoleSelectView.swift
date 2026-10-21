//
//  RoleSelectView.swift
//  PlayFeat
//
//  "Choose your role": Procurement, Chef or Front House. The roles the player
//  doesn't pick are run by stand-ins.
//

import SwiftUI

struct RoleSelectView: View {
    var onPlay: (KitchenRole) -> Void

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
                        RoleCard(role: role) { onPlay(role) }
                    }
                }
            }
            .designScaled()
        }
    }
}

#Preview {
    RoleSelectView(onPlay: { _ in })
        .environment(AudioManager())
}
