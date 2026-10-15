//
//  CarriedItemNode.swift
//  PlayFeat
//
//  Whatever a Procurement hand is holding, drawn the way Figma shows it: the
//  item inside a glassy bubble that follows the hand.
//

import SpriteKit

final class CarriedItemNode: SKNode {
    init(item: CarriedItem, diameter: CGFloat) {
        super.init()

        let bubble = SKSpriteNode(imageNamed: "HeldBubble")
        bubble.size = CGSize(width: diameter, height: diameter)
        bubble.zPosition = 1
        addChild(bubble)

        let art = SKSpriteNode(imageNamed: item.imageName)
        art.size = Self.artSize(for: item, art: art.size, diameter: diameter)
        addChild(art)

        if item == .dirtyTray {
            let dirt = SKSpriteNode(imageNamed: TrayArt.dirtImage)
            dirt.size = TrayArt.dirtSize(onTray: art.size)
            art.addChild(dirt)
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
        case .sliced, .cooked: diameter * 0.6
        case .dirtyTray, .cleanTray: diameter * 0.7
        }
        return CGSize(width: art.width / longest * target, height: art.height / longest * target)
    }
}
