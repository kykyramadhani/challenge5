//
//  ShiftCountdownOverlay.swift
//  PlayFeat
//
//  The countdown screen from Figma (669:188): the number over a 40% dark
//  scrim. The space background stands in for the camera only until the
//  first frame arrives; after that the live feed shows through the scrim, so
//  the player can settle in front of the camera while the count runs.
//

import SwiftUI

struct ShiftCountdownOverlay: View {
    /// Nil hides the number, e.g. while the camera permission card is up.
    let number: Int?
    let isCameraLive: Bool
    /// The count has run out but the camera isn't ready, so it is holding.
    let isWaitingForCamera: Bool

    var body: some View {
        ZStack {
            Image("SpaceBackground")
                .resizable()
                .scaledToFill()
                .opacity(isCameraLive ? 0 : 1)
                .animation(.easeOut(duration: 0.4), value: isCameraLive)
            Color.black.opacity(0.4)
            if let number {
                CountdownNumber(number: number)
                    .overlay(alignment: .bottom) {
                        if isWaitingForCamera { waitingCaption }
                    }
                    .designScaled()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// Hangs below the number so the number stays where Figma puts it.
    private var waitingCaption: some View {
        Text("Starting the camera…")
            .font(.atkinson(size: 32, weight: .bold))
            .foregroundStyle(.kitchenElevated)
            .fixedSize()
            .offset(y: 70)
    }
}

/// One number, popping in big and settling as each beat lands.
private struct CountdownNumber: View {
    let number: Int

    var body: some View {
        ZStack {
            Text(number, format: .number)
                .font(.atkinson(size: 200, weight: .black))
                .foregroundStyle(.kitchenElevated)
                .id(number)
                .transition(.asymmetric(insertion: .scale(scale: 1.6).combined(with: .opacity),
                                        removal: .scale(scale: 0.6).combined(with: .opacity)))
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: number)
    }
}

#Preview {
    ShiftCountdownOverlay(number: 3, isCameraLive: false, isWaitingForCamera: false)
}
