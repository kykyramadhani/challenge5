//
//  ButtonComponent.swift
//  GetCooking
//
//  Created by Owen Limantoro on 13/08/26.
//

import SwiftUI

struct ButtonComponent: View {
    var name: String
    var icon: String
    var action: () -> Void
    var buttonStyle: ButtonComponentStyle

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(buttonStyle.textColor)

                Text(name)
                    .font(.system(size: 34, weight: .bold))
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
    ButtonComponent(name: "Main Menu", icon: "house.fill", action: {}, buttonStyle: .primary)
}
