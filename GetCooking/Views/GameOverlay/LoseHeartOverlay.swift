//
//  LoseHeartOverlay.swift
//  GetCooking
//
//  Created by Owen Limantoro on 22/08/26.
//

import SwiftUI

struct LoseHeartOverlay: View {
    @ObservedObject var gameStateManager: GameStateManager
    @State private var opacity: Double = 0
    
    var body: some View {
        redBorder()
            .opacity(opacity)
            .allowsHitTesting(false)
            .onChange(of: gameStateManager.looseHeart) { _, isLosing in
                if isLosing { blink() }
            }
    }
    
    private func blink() {
        withAnimation(.easeInOut(duration: 0.2).repeatCount(6, autoreverses: true)) {
            opacity = 1
        } completion: {
            opacity = 0
            gameStateManager.looseHeart = false   // reset so it can fire again
        }
    }

}

struct redBorder : View {
    var body: some View {
        // Red warning around the edges
        LinearGradient(
            stops: [
                .init(color: .red.opacity(0.45), location: 0.0),
                .init(color: .red.opacity(0.15), location: 0.25),
                .init(color: .clear, location: 0.5),
                .init(color: .red.opacity(0.15), location: 0.75),
                .init(color: .red.opacity(0.45), location: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .ignoresSafeArea()
    }
}
