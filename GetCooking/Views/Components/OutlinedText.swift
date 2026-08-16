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
    /// SwiftUI has no text stroke, so this is four zero-radius shadows at the
    /// corners. They compound — each one shadows the result of the last — which
    /// fills the gaps between them and reads as a solid outline at heading
    /// sizes. Cheap enough for the handful of labels that use it, and far less
    /// machinery than dropping down to Core Text for a real stroke.
    func outlined(_ color: Color = .black, width: CGFloat = 3) -> some View {
        self
            .shadow(color: color, radius: 0, x: width, y: width)
            .shadow(color: color, radius: 0, x: -width, y: width)
            .shadow(color: color, radius: 0, x: width, y: -width)
            .shadow(color: color, radius: 0, x: -width, y: -width)
    }
}
