//
//  GameOver.swift
//  GetCooking
//
//  Created by Owen Limantoro on 12/08/26.
//

import SwiftUI

struct GameOverCard: View {
    let score: Int
    let onRestart: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Time's up!")
                .font(.largeTitle.bold())
            Text("You served \(score) \(score == 1 ? "dish" : "dishes")")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button("Play again", action: onRestart)
                .font(.headline)
                .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
}

#Preview {
    GameOverCard(score: 0) {
        return
    }
}
