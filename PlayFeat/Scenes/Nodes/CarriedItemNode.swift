//
//  CarriedItemNode.swift
//  PlayFeat
//
//  Whatever a hand is holding, drawn the way Figma shows it: the item inside
//  a glassy bubble that follows the hand. Front House's tray keeps the
//  dishes and drink already on it.
//

import SpriteKit

final class CarriedItemNode: SKNode {
    init(item: CarriedItem, diameter: CGFloat) {
        super.init()

        let bubble = SKSpriteNode(imageNamed: "HeldBubble")
        bubble.size = CGSize(width: diameter, height: diameter)
        // The scene ignores sibling order, so every layer gets its own z:
        // art 0, what's on it 1, the glass bubble over all of it.
        bubble.zPosition = 2
        addChild(bubble)

        let art = SKSpriteNode(imageNamed: item.imageName)
        art.size = Self.artSize(for: item, art: art.size, diameter: diameter)
        addChild(art)

        if item == .dirtyTray {
            let dirt = SKSpriteNode(imageNamed: TrayArt.dirtImage)
            dirt.size = TrayArt.dirtSize(onTray: art.size)
            dirt.zPosition = 1
            art.addChild(dirt)
        }
        if case let .servingTray(tray) = item {
            Self.lay(tray, on: art)
        }
    }

    /// The tray's dishes and drink as children of its art (SpriteKit: y up,
    /// origin at the art's centre).
    private static func lay(_ tray: ServingTray, on art: SKSpriteNode) {
        func place(_ image: String, at fraction: CGPoint, size: CGSize) {
            let node = SKSpriteNode(imageNamed: image)
            node.size = size
            node.position = CGPoint(x: (fraction.x - 0.5) * art.size.width, y: (0.5 - fraction.y) * art.size.height)
            node.zPosition = 1
            art.addChild(node)
        }
        let dish = art.size.width * TrayArt.dishWidth
        for (compartment, ingredient) in tray.dishes {
            place(ingredient.preparedImageName, at: TrayArt.center(of: compartment),
                  size: CGSize(width: dish, height: dish))
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Ingredients fill a little over half the bubble, as in the design;
    /// trays most of its width.
    private static func artSize(for item: CarriedItem, art: CGSize, diameter: CGFloat) -> CGSize {
        let longest = max(art.width, art.height)
        guard longest > 0 else { return .zero }
        let target: CGFloat = switch item {
        case .ingredient: diameter * 0.55
        case .sliced, .cooked, .dish: diameter * 0.6
        case .drink: diameter * 0.45
        case .dirtyTray, .cleanTray, .servingTray: diameter * 0.7
        }
        return CGSize(width: art.width / longest * target, height: art.height / longest * target)
    }
}
