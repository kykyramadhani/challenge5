//
//  DispenserPanel.swift
//  PlayFeat
//
//  The drink dispenser zoomed in (Figma 702:9367, 702:11597): the dispenser
//  under a lane showing the handle's way — left to open the tap, then, while
//  it runs, back right to close it. The bar fills with the glass.
//

import SwiftUI

struct DispenserPanel: View {
    let progress: Double
    let isTapOpen: Bool

    var body: some View {
        WorkstationPanel(title: "MAKE A PINCH AND FOLLOW THE PATTERN") {
            Image("Dispenser")
                .resizable()
                .scaledToFit()
                .frame(width: 204.1, height: 437.1)
                .offset(x: 435.1, y: 201.6)

            if isTapOpen {
                Capsule()
                    .fill(.progressGreenMid)
                    .frame(width: 10, height: 52)
                    .offset(x: 537, y: 618)
                    .transition(.opacity)
            }

            LeverLane(pointsLeft: !isTapOpen)
                .offset(x: 308, y: 350)

            PanelProgressBar(progress: progress)
                .offset(x: 247.2, y: 675.3)
        }
        .animation(.easeOut(duration: 0.2), value: isTapOpen)
    }
}

/// A shaded lane with a dashed arrow: the way to move the pinched handle.
private struct LeverLane: View {
    let pointsLeft: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 47)
            .fill(.laneShade.opacity(0.17))
            .frame(width: 465, height: 94)
            .overlay {
                // The chop arrow points down; a quarter turn makes it point
                // left (clockwise) or right.
                Image("ChopPatternArrow")
                    .resizable()
                    .frame(width: 50.7, height: 409)
                    .rotationEffect(.degrees(pointsLeft ? 90 : -90))
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    DispenserPanel(progress: 0.6, isTapOpen: true)
        .scaleEffect(0.6)
}
