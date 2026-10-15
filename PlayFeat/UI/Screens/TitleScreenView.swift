//
//  TitleScreenView.swift
//  PlayFeat
//
//  The first screen: the PlayFeat sign over the space sky. Fades in, floats
//  gently, and moves on to role selection on a tap or after a few seconds —
//  a player whose hands are busy shouldn't be stuck here.
//

import SwiftUI

struct TitleScreenView: View {
    var onStart: () -> Void

    @State private var isShown = false
    @State private var isFloating = false

    /// Figma's sign: 1114 × 524 on the 1376 × 1034 frame.
    private let logoSize = CGSize(width: 1114, height: 524)
    private let autoAdvanceDelay: Duration = .seconds(3)

    var body: some View {
        ZStack {
            Image("SpaceBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Image("PlayFeatLogo")
                .resizable()
                .scaledToFit()
                .frame(width: logoSize.width, height: logoSize.height)
                .offset(y: isFloating ? -10 : 10)
                .scaleEffect(isShown ? 1 : 0.85)
                .opacity(isShown ? 1 : 0)
                .accessibilityLabel("PlayFeat")
                .designScaled()
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onStart)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { isShown = true }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { isFloating = true }
        }
        .task {
            try? await Task.sleep(for: autoAdvanceDelay)
            if !Task.isCancelled { onStart() }
        }
    }
}

#Preview {
    TitleScreenView(onStart: {})
}
