//
//  ShopClosedPopUp.swift
//  GetCooking
//
//  Created by Owen Limantoro on 22/08/26.
//

import SwiftUI

/// A "coming soon" popup for something not built yet, with the game mascot.
/// Says the shop by default; role selection reuses it for the unplayable roles.
struct ShopComingSoonPopup: View {
    var title: LocalizedStringKey = "Shop Opening Soon!"
    var message: LocalizedStringKey = "Our shop is under maintanence — check back soon to spend your coins!"
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 24) {
                Image("Happy")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 260, height: 260)

                Text(title)
                    .font(.atkinson(size: 44, weight: .bold))
                    .foregroundStyle(.appTertiaryText)

                Text(message)
                    .font(.atkinson(size: 24, weight: .medium))
                    .foregroundStyle(.appTertiaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)

                ButtonComponent(
                    name: "Got it",
                    icon: "checkmark",
                    action: onClose,
                    buttonStyle: .primary
                )
                .padding(.top, 8)
            }
            .padding(56)
            .background(
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(.white)
            )
            .frame(maxWidth: 720)
            .padding(40)
        }
    }
}

#Preview {
    ShopComingSoonPopup(onClose: {})
        .environment(AudioManager())
}
