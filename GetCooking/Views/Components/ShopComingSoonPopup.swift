//
//  ShopClosedPopUp.swift
//  GetCooking
//
//  Created by Owen Limantoro on 22/08/26.
//

import SwiftUI

/// A "coming soon" popup for the not-yet-built shop, with the game mascot.
struct ShopComingSoonPopup: View {
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

                Text("Shop Opening Soon!")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.appTertiaryText)

                Text("Our shop is under maintanence — check back soon to spend your coins!")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
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
    ShopComingSoonPopup(onClose: {
        
    })
}
