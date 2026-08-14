//
//  ResetButtonNode.swift
//  GetCooking
//
//  Created by Owen Limantoro on 13/08/26.
//

import SpriteKit

final class ResetButtonNode: SKNode {
    let resetRadius: CGFloat
    private let circle: SKShapeNode
    private let arrow: SKSpriteNode

    init(radius: CGFloat) {
        self.resetRadius = radius
        
        // Circle
        circle = SKShapeNode(circleOfRadius: resetRadius)
        circle.fillColor = SKColor(
            red: 0.56,
            green: 0.51,
            blue: 0.82,
            alpha: 1
        )
        circle.strokeColor = .clear
        
        // Arrow
        let config = UIImage.SymbolConfiguration(
            pointSize: 50,
            weight: .bold
        )
        
        guard let image = UIImage(
            systemName: "arrow.counterclockwise",
            withConfiguration: config
        ) else {
            fatalError("Could not load SF Symbol: arrow.counterclockwise")
        }
        
        arrow = SKSpriteNode(
            texture: SKTexture(image: image)
        )
        
        super.init()
        
        addChild(circle)
        addChild(arrow)
        
        setupArrow()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupArrow() {
        arrow.color = .white
        arrow.colorBlendFactor = 1.0
        
        arrow.position = .zero
    }
}
