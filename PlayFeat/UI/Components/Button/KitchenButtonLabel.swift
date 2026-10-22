//
//  KitchenButtonLabel.swift
//  PlayFeat
//  Created by Owen Limantoro on 21/10/26.
//
//  The textured pink pill on the kitchen screens (PLAY ROLE, CONTINUE). The
//  texture is Figma's button art; the label is drawn on top so it can be
//  translated. Put it inside a `ClickButton`.
//

import SwiftUI

struct KitchenButtonLabel: View {
    let title: LocalizedStringKey
    /// An SF Symbol after the title, like CONTINUE's ▶.
    var systemImage: String? = nil
    /// The button's face, without its 3D base.
    var size = CGSize(width: 219, height: 63)

    /// The art's 3D base below the face. It's a Figma effect, which doesn't
    /// export, so it's added here.
    static let baseDepth: CGFloat = 13

    /// Label size for the face height: 24 pt on PLAY ROLE's 63 pt face.
    private static let labelShare: CGFloat = 24 / 63

    var body: some View {
        HStack(spacing: size.height * 0.15) {
            Text(title)
            if let systemImage {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }
        }
        .font(.atkinson(size: size.height * Self.labelShare, weight: .black))
        .tracking(0.48)
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.15), radius: 0, y: 2.5)
        .frame(width: size.width, height: size.height)
        .background(alignment: .top) {
            Image("PlayRoleButton")
                .resizable()
                .frame(width: size.width, height: size.height + Self.baseDepth)
                .shadow(color: .black.opacity(0.2), radius: 0, y: 12.7)
        }
        .frame(height: size.height + Self.baseDepth, alignment: .top)
        .shadow(color: .black.opacity(0.25), radius: 1.3, y: 5)
    }
}

#Preview {
    VStack(spacing: 40) {
        KitchenButtonLabel(title: "PLAY ROLE")
        KitchenButtonLabel(title: "CONTINUE", systemImage: "play.fill", size: CGSize(width: 286, height: 72))
    }
    .padding()
    .background(.black)
}
