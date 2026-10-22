//
//  RoleCard.swift
//  PlayFeat
//
//  One role on the role-selection screen: the alien chef in its portal, the
//  role's name and job, and a PLAY ROLE button. Sized as in Figma (362 × 453).
//

import SwiftUI

struct RoleCard: View {
    let role: KitchenRole
    var onPlay: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image("RoleAlienChef")
                .resizable()
                .scaledToFit()
                .frame(width: 197, height: 197)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                Text(role.title)
                    .font(.atkinson(size: 32, weight: .heavy))
                    .foregroundStyle(.kitchenInk)
                    .frame(width: 280)
                Text(role.summary)
                    .font(.atkinson(size: 16, weight: .medium))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .frame(width: 248, height: 44)
            }

            ClickButton(action: onPlay) {
                KitchenButtonLabel(title: "PLAY ROLE")
            }
            .buttonStyle(.plain)
        }
        .padding(EdgeInsets(top: 24, leading: 32, bottom: 36, trailing: 32))
        .frame(width: 362, height: 453)
        .background(.kitchenPageTint, in: RoundedRectangle(cornerRadius: 46, style: .continuous))
        .shadow(color: .nebulaPink, radius: 10)
    }
}

#Preview {
    RoleCard(role: .procurement, onPlay: {})
        .padding()
        .background(.black)
        .environment(AudioManager())
}
