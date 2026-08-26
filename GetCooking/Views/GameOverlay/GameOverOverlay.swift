//
//  GameOverOverlay.swift
//  GetCooking
//
//  The brief "Game Over" beat shown the instant a run ends, before the
//  results screen. A dark scrim drops the frozen board back and the title
//  pops up from nothing; once it has held for a moment, `onFinished` hands
//  off to the post-game summary.
//

import SwiftUI

struct GameOverOverlay: View {
    /// Called once the title has finished animating and held — the caller
    /// navigates to the results screen here.
    var onFinished: () -> Void

    @State private var titleScale: CGFloat = 0
    @State private var scrimOpacity: CGFloat = 0

    /// How long the whole cover lasts before handing off: the spring settle
    /// plus a beat to read the words.
    private let holdBeforeHandoff: TimeInterval = 1.4

    var body: some View {
        ZStack {
            // Transparent black — the last frame of the board still shows
            // through underneath.
            Color.black
                .opacity(0.6 * scrimOpacity)
                .ignoresSafeArea()

            Text("Shift Over")
                .font(.custom(size: 96, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
                .scaleEffect(titleScale)
                .multilineTextAlignment(.center)
        }
        .onAppear {
            // Scrim eases in flat; the title springs so it overshoots and
            // settles, reading as a stamp landing rather than a plain grow.
            withAnimation(.easeOut(duration: 0.3)) {
                scrimOpacity = 1
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                titleScale = 1
            }

            // Hand off to the results once it has landed and been read.
            DispatchQueue.main.asyncAfter(deadline: .now() + holdBeforeHandoff) {
                onFinished()
            }
        }
    }
}

#Preview {
    ZStack {
        Color.appPrimary.ignoresSafeArea()
        GameOverOverlay(onFinished: {})
    }
}
