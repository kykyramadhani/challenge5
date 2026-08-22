//
//  ButtonComponent.swift
//  GetCooking
//
//  Created by Owen Limantoro on 15/08/26.
//

import SwiftUI

struct SettingsButton: View {
    var action: () -> Void

    var body: some View {
        GeometryReader { proxy in
            Button(action: {
                AudioManager.shared.play(.uiClick)
                action()
            }) {
                Image(systemName: "gear")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 100, height: 100)
                    .background(.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
            }
            .position(
                x: proxy.size.width * 0.88,
                y: proxy.size.height * 0.1
            )

        }
    }
}

#Preview {
    SettingsButton {
        print("test")
    }
}
