//
//  WorkstationPanel.swift
//  PlayFeat
//
//  The zoomed-in frame the cutting board, the sink and the broth pot open
//  in: a purple screwed-on plate around a pale page, the instruction at the
//  top, the work in the middle and progress at the bottom.
//  Figma size, 1074 × 868; content is placed in the outer frame's points.
//

import SwiftUI

struct WorkstationPanel<Content: View>: View {
    var title: LocalizedStringKey = "MOVE YOUR HAND BASED ON THE PATTERN"
    @ViewBuilder let content: Content

    static var size: CGSize { CGSize(width: 1074, height: 868) }
    private let inset: CGFloat = 55

    var body: some View {
        ZStack(alignment: .topLeading) {
            KitchenPanelFrame(size: Self.size, cornerRadius: 53)

            RoundedRectangle(cornerRadius: 53)
                .fill(Color.kitchenPageTint
                    .shadow(.inner(color: .black.opacity(0.37), radius: 4.6, y: -4.6))
                    .shadow(.inner(color: .black.opacity(0.39), radius: 2.7, y: 4.6)))
                .frame(width: Self.size.width - inset * 2, height: Self.size.height - inset * 2)
                .offset(x: inset, y: inset)

            Text(title)
                .font(.atkinson(size: 40, weight: .heavy))
                .tracking(-0.8)
                .foregroundStyle(.kitchenInk)
                .frame(width: Self.size.width, height: 55)
                .offset(y: inset * 2)

            content
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }
}
