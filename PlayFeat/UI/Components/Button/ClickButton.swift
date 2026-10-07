//
//  ClickButton.swift
//  PlayFeat
//
//  A Button with the UI click sound built in. Use it instead of `Button` for
//  every tappable control, so the sound lives in one place and a new button
//  can't forget it.
//

import SwiftUI

struct ClickButton<Label: View>: View {
    @Environment(AudioManager.self) private var audio

    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button {
            audio.play(.uiClick)
            action()
        } label: {
            label()
        }
    }
}

#Preview {
    ClickButton(action: {}) {
        Text("Tap me")
    }
    .environment(AudioManager())
}
