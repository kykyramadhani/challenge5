//
//  SoupPanel.swift
//  PlayFeat
//
//  The broth pot zoomed in (Figma 616:18687): coral lettuce in broth on the
//  hob under a dashed circle showing the pinch-and-stir motion. The circle
//  turns and the bar fills only as ChefGame credits circles stirred with a
//  pinched hand.
//

import SwiftUI

struct SoupPanel: View {
    let progress: Double

    private let circleDiameter: CGFloat = 418.7

    var body: some View {
        WorkstationPanel(title: "PINCH YOUR HAND BASED ON THE PATTERN") {
            ZStack(alignment: .topLeading) {
                Image("StoveBurner")
                    .resizable()
                    .frame(width: 401.9, height: 401.9)
                    .offset(x: 54.3, y: 20.1)

                Image("BrothPotSoup")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 519.5, height: 412.4)
                    .offset(x: -5.9, y: 0.4)

                CirclePattern(diameter: circleDiameter, turn: .degrees(360 * progress))
                    .offset(x: 47, y: 2.6)
                    .animation(.easeOut(duration: 0.25), value: progress)
            }
            .frame(width: 508.4, height: 422, alignment: .topLeading)
            .offset(x: 283, y: 201.6)
            .accessibilityHidden(true)

            PanelProgressBar(progress: progress)
                .offset(x: 247, y: 663)
        }
    }
}

#Preview {
    SoupPanel(progress: 0.6)
        .scaleEffect(0.6)
}
