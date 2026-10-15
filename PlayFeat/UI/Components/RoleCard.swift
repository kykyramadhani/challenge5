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
                PlayRoleLabel()
            }
            .buttonStyle(.plain)
        }
        .padding(EdgeInsets(top: 24, leading: 32, bottom: 36, trailing: 32))
        .frame(width: 362, height: 453)
        .background(.kitchenPageTint, in: RoundedRectangle(cornerRadius: 46, style: .continuous))
        .shadow(color: .nebulaPink, radius: 10)
    }
}

/// The textured pink pill. The texture is Figma's button art; the label is
/// drawn on top so it can be translated.
private struct PlayRoleLabel: View {
    var body: some View {
        Text("PLAY ROLE")
            .font(.atkinson(size: 24, weight: .black))
            .tracking(0.48)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.15), radius: 0, y: 2.5)
            .frame(width: 219, height: 63)
            .background(alignment: .top) {
                // The art's 3D base is a Figma effect, which doesn't export.
                Image("PlayRoleButton")
                    .resizable()
                    .frame(width: 219, height: 76)
                    .shadow(color: .black.opacity(0.2), radius: 0, y: 12.7)
            }
            .frame(height: 76, alignment: .top)
            .shadow(color: .black.opacity(0.25), radius: 1.3, y: 5)
    }
}

#Preview {
    RoleCard(role: .procurement, onPlay: {})
        .padding()
        .background(.black)
        .environment(AudioManager())
}
