//
//  CirclePattern.swift
//  PlayFeat
//
//  The dashed circle a circling motion follows — scrubbing a tray, stirring
//  soup — with its arrowhead sitting on the line at the top, pointing
//  clockwise along it. The arrowhead is placed from the circle's own
//  geometry rather than copied from Figma's coordinates (which, for a rotated
//  layer, describe its pre-rotation box and put it inside the circle).
//

import SwiftUI

struct CirclePattern: View {
    let diameter: CGFloat
    /// Turns the whole pattern, arrow included, to show progress.
    var turn: Angle = .zero

    /// The chevron art's own size, stroke padding included (it points down).
    private static let arrowSize = CGSize(width: 50.7, height: 29.3)

    var body: some View {
        Circle()
            .fill(.patternBlue.opacity(0.15))
            .overlay(Circle().stroke(.patternBlue, style: StrokeStyle(lineWidth: 5, dash: [20, 20])))
            .overlay { arrowhead.position(x: diameter / 2, y: 0) }
            .frame(width: diameter, height: diameter)
            .rotationEffect(turn)
            .accessibilityHidden(true)
    }

    /// Centred on the topmost point of the line, turned from pointing down to
    /// pointing right: the way a clockwise circle runs at the top.
    private var arrowhead: some View {
        Image("WashPatternArrow")
            .resizable()
            .frame(width: Self.arrowSize.width, height: Self.arrowSize.height)
            .rotationEffect(.degrees(-90))
    }
}

#Preview {
    CirclePattern(diameter: 300)
        .padding(60)
        .background(.white)
}
