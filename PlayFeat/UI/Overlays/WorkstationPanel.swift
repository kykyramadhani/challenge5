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
    private let screwInset: CGFloat = 27.5

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 53)
                .fill(.kitchenPurple)

            RoundedRectangle(cornerRadius: 53)
                .fill(Color.kitchenPageTint
                    .shadow(.inner(color: .black.opacity(0.37), radius: 4.6, y: -4.6))
                    .shadow(.inner(color: .black.opacity(0.39), radius: 2.7, y: 4.6)))
                .frame(width: Self.size.width - inset * 2, height: Self.size.height - inset * 2)
                .offset(x: inset, y: inset)

            screws

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

    private var screws: some View {
        ForEach(Array(screwCenters.enumerated()), id: \.offset) { _, center in
            Image("PanelScrew")
                .resizable()
                .frame(width: screwInset, height: screwInset)
                .position(center)
        }
    }

    private var screwCenters: [CGPoint] {
        let near = screwInset * 1.5
        return [
            CGPoint(x: near, y: near),
            CGPoint(x: Self.size.width - near, y: near),
            CGPoint(x: near, y: Self.size.height - near),
            CGPoint(x: Self.size.width - near, y: Self.size.height - near),
        ]
    }
}
