//
//  WashingPanel.swift
//  PlayFeat
//
//  The sink zoomed in: the dirty tray under a dashed circle showing the
//  open-hand scrubbing motion. The dirt fades and the bar fills only as
//  ProcurementGame credits recognized circles.
//

import SwiftUI

struct WashingPanel: View {
    let progress: Double

    private let traySize = CGSize(width: 522.7, height: 424.8)
    private let circleDiameter: CGFloat = 418.7

    var body: some View {
        WorkstationPanel {
            ZStack(alignment: .topLeading) {
                TrayArtView(isDirty: true, dirtOpacity: 1 - progress, size: traySize)
                    .animation(.easeOut(duration: 0.2), value: progress)

                CirclePattern(diameter: circleDiameter)
                    .offset(x: 47.2, y: 2.6)
            }
            .frame(width: traySize.width, height: traySize.height, alignment: .topLeading)
            .offset(x: 276, y: 202)
            .accessibilityHidden(true)

            PanelProgressBar(progress: progress)
                .offset(x: 247, y: 663)
        }
    }
}

#Preview {
    WashingPanel(progress: 0.6)
        .scaleEffect(0.6)
}
