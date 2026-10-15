//
//  KitchenLayout.swift
//  PlayFeat
//
//  What every role's screen shares, in view space (origin top-left, y down):
//  how a Figma rect lands on this screen, and where the HUD — shift clock,
//  order rail — and the zoomed-in panel sit. Each role's layout adds its own
//  worktop. The SwiftUI furniture is drawn from these rects and the scene
//  hit-tests hands against the same ones, so what the player sees is exactly
//  what their hand can reach.
//
//  Numbers are the Figma frames' (1376 × 1034). Sizes scale with the design
//  canvas; heights are placed as a fraction of the screen, and each item keeps
//  the screen edge (or centre) it hangs off in the design, so narrower iPads
//  only lose margin.
//

import CoreGraphics

/// The screen edge (or centre) a Figma rect hangs off.
enum FigmaAnchor { case leading, center, trailing }

protocol KitchenLayout {
    var size: CGSize { get }
    init(size: CGSize)
}

extension KitchenLayout {
    static var figmaSize: CGSize { CGSize(width: 1376, height: 1034) }

    var scale: CGFloat { DesignCanvas.scale(for: size) }

    /// A carried item's bubble, and every floating one.
    var heldBubbleDiameter: CGFloat { 161 * scale }

    // MARK: - HUD

    var shiftClock: CGRect { rect(x: 28, y: 24, width: 244, height: 151, .leading) }

    /// The four order tickets, leftmost (active) first.
    func ticket(_ index: Int) -> CGRect {
        let xs: [CGFloat] = [545, 743.9, 930.7, 1122]
        return rect(x: xs[index], y: 0, width: 162, height: 295, .center)
    }

    // MARK: - Zoomed-in panels

    /// The cutting, washing and stirring panel, frame included.
    var panel: CGRect { rect(x: 170, y: 75, width: 1074, height: 868, .center) }

    /// Where hands count while a panel is open: its whole inner page, so a
    /// stroke that drifts past the work's edge still counts.
    var workArea: CGRect { panel.insetBy(dx: 55 * scale, dy: 55 * scale) }

    // MARK: - Mapping

    /// A Figma rect placed on this screen.
    func rect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, _ anchor: FigmaAnchor) -> CGRect {
        let figmaCenterX = x + width / 2
        let centerX: CGFloat = switch anchor {
        case .leading: figmaCenterX * scale
        case .center: size.width / 2 + (figmaCenterX - Self.figmaSize.width / 2) * scale
        case .trailing: size.width - (Self.figmaSize.width - figmaCenterX) * scale
        }
        let centerY = (y + height / 2) / Self.figmaSize.height * size.height
        let scaled = CGSize(width: width * scale, height: height * scale)
        return CGRect(x: centerX - scaled.width / 2, y: centerY - scaled.height / 2,
                      width: scaled.width, height: scaled.height)
    }
}
