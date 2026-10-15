//
//  TrayBubble.swift
//  PlayFeat
//
//  The bubble beside the Front House portal where trays wait: dirty ones
//  back from serving, stacked when several pile up, and a washed one on top
//  ready to send back. Figma size, 237 × 237.
//

import SwiftUI

struct TrayBubble: View {
    let dirtyTrays: Int
    let cleanTrays: Int

    static let size: CGFloat = 237
    private static let traySize = CGSize(width: 167, height: 136)
    /// How far each extra tray in the pile is shifted.
    private static let stackStep: CGFloat = 10
    private static let maxShown = 3

    var body: some View {
        ZStack {
            ForEach(0..<min(dirtyTrays, Self.maxShown), id: \.self) { index in
                TrayArtView(isDirty: true)
                    .offset(x: -CGFloat(index) * Self.stackStep, y: -CGFloat(index) * Self.stackStep)
                    .zIndex(-Double(index))
            }
            if cleanTrays > 0 {
                TrayArtView(isDirty: false).zIndex(1)
            }
            Image("HeldBubble")
                .resizable()
                .frame(width: Self.size, height: Self.size)
                .zIndex(2)
        }
        .frame(width: Self.size, height: Self.size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Trays"))
    }
}

#Preview {
    HStack {
        TrayBubble(dirtyTrays: 2, cleanTrays: 0)
        TrayBubble(dirtyTrays: 0, cleanTrays: 1)
    }
    .padding()
    .background(.gray)
}
