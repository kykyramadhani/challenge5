//
//  PlateNode.swift
//  GetCooking
//
//  Created by Owen Limantoro on 14/08/26.
//

import SpriteKit

final class PlateNode: SKNode {

    private let plateRadius: CGFloat
    private(set) var sprite: SKSpriteNode?
    private(set) var fallbackShape: SKShapeNode?

    init(radius: CGFloat) {
        self.plateRadius = radius

        super.init()

        buildPlate()
        layout()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildPlate() {
        if let texture = TrimmedArt.texture(named: GameArt.plate) {
            let plate = SKSpriteNode(texture: texture)
            addChild(plate)
            sprite = plate
        } else {
            let plate = SKShapeNode(circleOfRadius: plateRadius)
            plate.fillColor = .white
            plate.strokeColor = SKColor(white: 0.7, alpha: 1)
            plate.lineWidth = 4

            addChild(plate)
            fallbackShape = plate
        }
    }

    func layout() {
        if let sprite, let texture = sprite.texture {
            sprite.size = IngredientNode.aspectFit(
                texture.size(),
                into: plateRadius * 2
            )

            sprite.position = .zero
        } else {
            fallbackShape?.path = CGPath(
                ellipseIn: CGRect(
                    x: -plateRadius,
                    y: -plateRadius,
                    width: plateRadius * 2,
                    height: plateRadius * 2
                ),
                transform: nil
            )

            fallbackShape?.position = .zero
        }
    }
}
