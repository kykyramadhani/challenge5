//
//  GameScene+Layout.swift
//  GetCooking
//
//  Creates and positions the plate and trash bin.
//

import SpriteKit

extension GameScene {

    /// One-time setup: creates the plate container and trash bin.
    func buildStaticNodes() {
        let container = SKNode()
        container.zPosition = 1
        addChild(container)
        plateContainer = container

        if let texture = TrimmedArt.texture(named: GameArt.plate) {
            let plate = SKSpriteNode(texture: texture)
            container.addChild(plate)
            plateSprite = plate
        } else {
            let plate = SKShapeNode(circleOfRadius: plateRadius)
            plate.fillColor = .white
            plate.strokeColor = SKColor(white: 0.7, alpha: 1)
            plate.lineWidth = 4
            container.addChild(plate)
            plateNode = plate
        }

        let trash = SKShapeNode(circleOfRadius: trashRadius)
        trash.fillColor = SKColor(red: 0.85, green: 0.3, blue: 0.3, alpha: 1)
        trash.strokeColor = .clear
        trash.zPosition = 1
        let label = SKLabelNode(text: "🗑")
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.fontSize = 40
        trash.addChild(label)
        addChild(trash)
        trashNode = trash
        trashLabel = label

        layoutStaticNodes()
    }

    /// Re-sizes and re-positions everything after a rotation or size change.
    func layoutStaticNodes() {
        guard size.width > 0, size.height > 0 else { return }

        if let plateSprite, let texture = plateSprite.texture {
            plateSprite.size = IngredientNode.aspectFit(texture.size(), into: plateRadius * 2)
            plateSprite.position = .zero
        } else {
            plateNode?.path = CGPath(
                ellipseIn: CGRect(x: -plateRadius, y: -plateRadius,
                                  width: plateRadius * 2, height: plateRadius * 2),
                transform: nil
            )
            plateNode?.position = .zero
        }
        plateContainer?.position = plateHome

        let inset = trashRadius + 16
        trashNode?.path = CGPath(
            ellipseIn: CGRect(x: -trashRadius, y: -trashRadius,
                              width: trashRadius * 2, height: trashRadius * 2),
            transform: nil
        )
        trashNode?.position = CGPoint(x: size.width - inset, y: inset)
        trashLabel?.fontSize = trashRadius * 0.8
    }

    /// Tears down the old plate container and creates a fresh one.
    /// Used after the serve animation slides the plate off-screen.
    func rebuildPlate() {
        let container = SKNode()
        container.zPosition = 1
        addChild(container)
        plateContainer = container

        if let texture = TrimmedArt.texture(named: GameArt.plate) {
            let plate = SKSpriteNode(texture: texture)
            plate.size = IngredientNode.aspectFit(texture.size(), into: plateRadius * 2)
            container.addChild(plate)
            plateSprite = plate
            plateNode = nil
        } else {
            let plate = SKShapeNode(circleOfRadius: plateRadius)
            plate.fillColor = .white
            plate.strokeColor = SKColor(white: 0.7, alpha: 1)
            plate.lineWidth = 4
            container.addChild(plate)
            plateNode = plate
            plateSprite = nil
        }
        container.position = plateHome
    }
}
