//
//  ButtonComponent.swift
//  GetCooking
//
//  Created by Owen Limantoro on 13/08/26.
//

import SwiftUI

struct ButtonComponent: View {
    var name: LocalizedStringKey
    var icon: String
    var action: () -> Void
    var buttonStyle: ButtonComponentStyle

    var body: some View {
        // Every menu button routes through here, so the click sound lives in one
        // place rather than at each call site.
        Button(action: {
            AudioManager.shared.play(.uiClick)
            action()
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(buttonStyle.textColor)

                Text(name)
                    .font(.atkinson(size: 34, weight: .bold))
                    .foregroundStyle(buttonStyle.textColor)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 24)
            .background(
                Capsule()
                    .fill(buttonStyle.bg)
            )
        }
    }
}

#Preview {
    ButtonComponent(name: "Main Menu", icon: "house.fill", action: {}, buttonStyle: .text)
}
