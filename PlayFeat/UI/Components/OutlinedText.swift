//
//  OutlinedText.swift
//  GetCooking
//
//  The chunky black outline the game's headings wear, so they stay readable
//  over whatever the camera happens to be showing behind them.
//

import SwiftUI

extension View {
    /// Draws a hard outline around the view.
    ///
    /// SwiftUI has no text stroke, so the outline is the view's own silhouette
    /// stamped in a ring behind it — the union of the stamps is the glyphs
    /// grown outward by `width`, which is what a stroke would have drawn.
    ///
    /// The previous version used four zero-radius shadows at the corners, which
    /// is cheaper but wrong in two ways: shadows compound (each one shadows the
    /// result of the last, so the corners came out twice as thick as the sides)
    /// and four diagonal copies leave stair-step notches wherever a curve turns.
    /// Stamps taken from the *original* at even angles have neither problem.
    func outlined(_ color: Color = .black, width: CGFloat = 3) -> some View {
        background {
            ZStack {
                ForEach(0 ..< Self.outlineStamps, id: \.self) { step in
                    let angle = 2 * .pi * Double(step) / Double(Self.outlineStamps)
                    color
                        .mask { self }
                        .offset(x: width * cos(angle), y: width * sin(angle))
                }
            }
        }
    }

    /// Enough stamps that neighbours overlap at the widths used here (4pt puts
    /// them ~1.5pt apart, far less than any glyph stem), so the ring reads as
    /// one continuous edge rather than a row of dots.
    private static var outlineStamps: Int { 16 }
}
