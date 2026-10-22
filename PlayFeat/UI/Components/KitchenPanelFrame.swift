//
//  KitchenPanelFrame.swift
//  PlayFeat
//  Created by Owen Limantoro on 21/10/26.
//
//  The kitchen's purple panel with a screw in each corner: the frame behind
//  the workstation panels and the shift report. Whatever goes on it is drawn
//  by the panel using it.
//

import SwiftUI

struct KitchenPanelFrame: View {
    let size: CGSize
    let cornerRadius: CGFloat

    private static let screwSize: CGFloat = 27.5

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.kitchenPurple)

            ForEach(Array(screwCenters.enumerated()), id: \.offset) { _, center in
                Image("PanelScrew")
                    .resizable()
                    .frame(width: Self.screwSize, height: Self.screwSize)
                    .position(center)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var screwCenters: [CGPoint] {
        let near = Self.screwSize * 1.5
        return [
            CGPoint(x: near, y: near),
            CGPoint(x: size.width - near, y: near),
            CGPoint(x: near, y: size.height - near),
            CGPoint(x: size.width - near, y: size.height - near),
        ]
    }
}

#Preview {
    KitchenPanelFrame(size: CGSize(width: 765, height: 794), cornerRadius: 45)
        .padding()
        .background(.black)
}
