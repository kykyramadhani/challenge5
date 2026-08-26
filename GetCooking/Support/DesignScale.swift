//
//  DesignScale.swift
//  GetCooking
//
//  Every screen in this app was drawn against one canvas — the same
//  1366×1024 iPad page `TutorialView` measures its artwork in — and the point
//  values scattered through the views (a 52pt coin, 36pt padding, a 44pt
//  score) are all sized for it. On a phone, which is roughly a third of that
//  canvas, those numbers are simply too big: the HUD row alone is wider than
//  the screen.
//
//  So rather than re-tune a hundred numbers per device, a screen lays itself
//  out on the canvas it was designed for and the whole thing is scaled down to
//  fit. Same layout, same proportions, just smaller — which is also why the
//  fraction-of-the-screen layouts (GameOpening and friends) come out
//  bit-identical: a fraction of a canvas that is 1/s the screen, scaled by s,
//  is the same fraction of the screen it always was.
//

import SwiftUI

extension View {
    /// Lays this screen out on the design canvas and scales it to fit.
    ///
    /// On iPad this returns the view *itself*, with no wrapper of any kind —
    /// the layouts here were tuned on iPad and must stay exactly as they are.
    /// Only phones get the canvas.
    ///
    /// Apply it to UI layers only. The camera preview and the SpriteKit board
    /// are deliberately left outside: they already fill whatever they are
    /// given, and laying them out on an oversized canvas would have SpriteKit
    /// rendering a framebuffer several times bigger than the screen.
    @ViewBuilder
    func designScaled() -> some View {
        if DesignCanvas.isScaled {
            modifier(DesignScaled())
        } else {
            self
        }
    }
}

enum DesignCanvas {
    /// The page size the art and every hardcoded point value assume.
    static let size = TutorialView.pageSize

    /// Phones only — see `designScaled()`.
    static var isScaled: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    /// The scale a view is actually drawn at: the canvas scale on a phone,
    /// and exactly 1 everywhere the canvas is not applied. Anything sized in
    /// canvas points but living *outside* the canvas — the SpriteKit board —
    /// has to multiply by this by hand.
    static func appliedScale(for available: CGSize) -> CGFloat {
        isScaled ? scale(for: available) : 1
    }

    /// The width `available` would have if it were the canvas's shape.
    ///
    /// A layout that *sizes* things as a fraction of the width but *positions*
    /// them as a fraction of the height only holds together while the screen is
    /// roughly the canvas's shape. A phone in landscape is nearly twice as wide
    /// for its height as the canvas is, which is what made the menu logo grow
    /// until it swallowed the screen. Sizing against this keeps each element the
    /// same fraction of the screen's *height* that it is on the canvas.
    ///
    /// Returns the width untouched wherever the canvas isn't applied.
    static func layoutWidth(for available: CGSize) -> CGFloat {
        guard isScaled, available.height > 0 else { return available.width }
        return min(available.width, available.height * (size.width / size.height))
    }

    /// How much of the canvas fits in `available`.
    ///
    /// The canvas is turned to match the screen's orientation first, so the
    /// game comes out the same size held either way round; without that, a
    /// portrait phone would be measured against a landscape canvas and shrink
    /// to about two thirds of the size it needs to be.
    static func scale(for available: CGSize) -> CGFloat {
        guard available.width > 0, available.height > 0 else { return 1 }

        let canvas = available.width > available.height
            ? size
            : CGSize(width: size.height, height: size.width)

        return min(1, min(available.width / canvas.width, available.height / canvas.height))
    }
}

/// Frames the content at screen-size-divided-by-scale, then scales it back
/// down — so the content believes it has a canvas-sized screen to work with
/// and lands on the real one pixel for pixel.
private struct DesignScaled: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let scale = DesignCanvas.appliedScale(for: proxy.size)

            content
                .frame(width: proxy.size.width / scale, height: proxy.size.height / scale)
                .scaleEffect(scale)
                // scaleEffect leaves the layout size alone, so the scaled
                // content still measures a canvas across; this re-centres it
                // over the screen it actually covers.
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }
}
