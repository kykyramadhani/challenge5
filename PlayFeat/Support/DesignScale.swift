//
//  DesignScale.swift
//  GetCooking
//
//  Every screen in this app was drawn against one canvas — the same
//  1366×1024 iPad page `TutorialView` measures its artwork in — and the point
//  values scattered through the views (a 52pt coin, 36pt padding, a 44pt
//  score) are all sized for it. Only a 13" iPad actually *is* that canvas:
//  an iPad mini (1133×744) is under three quarters of it and a phone roughly
//  a third, so on anything smaller those numbers run off the screen.
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
    /// Every device gets the canvas — iPad mini, 11", Split View and Stage
    /// Manager windows included. A 13" iPad lands at a scale of exactly 1,
    /// so the screen it was tuned on is untouched.
    ///
    /// Apply it to UI layers only. The camera preview and the SpriteKit board
    /// are deliberately left outside: they already fill whatever they are
    /// given, and laying them out on an oversized canvas would have SpriteKit
    /// rendering a framebuffer several times bigger than the screen.
    func designScaled() -> some View {
        modifier(DesignScaled())
    }
}

enum DesignCanvas {
    /// The page size the art and every hardcoded point value assume.
    static let size = TutorialView.pageSize

    /// The width `available` would have if it were the canvas's shape.
    ///
    /// A layout that *sizes* things as a fraction of the width but *positions*
    /// them as a fraction of the height only holds together while the screen is
    /// roughly the canvas's shape. A phone in landscape is nearly twice as wide
    /// for its height as the canvas is, which is what made the menu logo grow
    /// until it swallowed the screen. Sizing against this keeps each element the
    /// same fraction of the screen's *height* that it is on the canvas.
    static func layoutWidth(for available: CGSize) -> CGFloat {
        guard available.height > 0 else { return available.width }
        return min(available.width, available.height * (size.width / size.height))
    }

    /// How much of the canvas fits in `available` — never more than 1, so a
    /// screen bigger than the canvas keeps the sizes it was designed at.
    ///
    /// Anything sized in canvas points but living *outside* the canvas — the
    /// SpriteKit board — has to multiply by this by hand.
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
            let scale = DesignCanvas.scale(for: proxy.size)

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

#if DEBUG
/// Debug-build readout of what the canvas is doing on this screen: the real
/// size in points, the scale the canvas is drawn at, and the canvas size the
/// screens actually lay out on. Pinned to the root so it follows every screen
/// and window resize (Split View, Stage Manager, rotation).
///
/// Ignores touches, so it can sit over the game without stealing a tap.
struct DesignCanvasDebugBadge: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let scale = DesignCanvas.scale(for: size)

            Text(String(
                format: "%.0f×%.0fpt  ·  scale %.3f  ·  canvas %.0f×%.0f",
                size.width, size.height, scale,
                size.width / scale, size.height / scale
            ))
            .font(.system(size: 11, weight: .semibold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.6), in: Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 4)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// Launch arguments for checking layouts on a single simulator, without
/// rotating it or tapping through the menus by hand. Add them under the
/// scheme's Run ▸ Arguments, or pass them to `simctl launch`:
///
///     -debugScreenSize 1133x744   lay the app out at this size (here an
///                                 iPad mini in landscape), shrunk to fit
///                                 whatever screen it is really on
///     -debugRotateAfter 8         swap that size's width and height after
///                                 8s, to exercise a mid-game rotation
///     -debugGameplay YES          skip onboarding, tutorial and seat check
///                                 and open straight onto the board
enum DebugLaunch {
    static var screenSize: CGSize? {
        let parts = (UserDefaults.standard.string(forKey: "debugScreenSize") ?? "")
            .split(separator: "x")
            .compactMap { Double($0) }
        guard parts.count == 2, parts[0] > 0, parts[1] > 0 else { return nil }
        return CGSize(width: parts[0], height: parts[1])
    }

    static var rotateAfter: TimeInterval? {
        let delay = UserDefaults.standard.double(forKey: "debugRotateAfter")
        return delay > 0 ? delay : nil
    }

    static var skipToGameplay: Bool {
        UserDefaults.standard.bool(forKey: "debugGameplay")
    }
}

extension View {
    /// Applies `-debugScreenSize` / `-debugRotateAfter`. A no-op without them.
    @ViewBuilder
    func debugScreenSize() -> some View {
        if let size = DebugLaunch.screenSize {
            modifier(DebugScreenSize(size: size))
        } else {
            self
        }
    }
}

/// Same trick as `DesignScaled`, the other way round: the app is framed at the
/// requested size and shrunk onto the real screen, so every GeometryReader
/// inside — the design canvas, the SpriteKit board — sees the fake size.
private struct DebugScreenSize: ViewModifier {
    let size: CGSize
    @State private var rotated = false

    func body(content: Content) -> some View {
        let current = rotated ? CGSize(width: size.height, height: size.width) : size

        GeometryReader { proxy in
            let fit = min(proxy.size.width / current.width, proxy.size.height / current.height)

            content
                .frame(width: current.width, height: current.height)
                .border(.red)
                .scaleEffect(fit)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        // Without this the real screen's insets leak into the fake one.
        .ignoresSafeArea()
        .background(.black)
        .task {
            guard let delay = DebugLaunch.rotateAfter else { return }
            try? await Task.sleep(for: .seconds(delay))
            rotated = true
        }
    }
}
#endif
