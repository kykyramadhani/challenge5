//
//  ResetButtonNode.swift
//  GetCooking
//
//  Created by Owen Limantoro on 13/08/26.
//

import SpriteKit

final class ResetButtonNode: SKNode {
    private let circle: SKShapeNode
    private let arrow: SKSpriteNode
    private let label: SKLabelNode

    override init() {
        // Circle
        circle = SKShapeNode(circleOfRadius: 100)
        circle.fillColor = SKColor(
            red: 0.56,
            green: 0.51,
            blue: 0.82,
            alpha: 1
        )
        circle.strokeColor = .clear
        
        // Arrow
        let config = UIImage.SymbolConfiguration(
            pointSize: 90,
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
        
        // Label
        label = SKLabelNode(text: "Reset")
        
        super.init()
        
        addChild(circle)
        addChild(arrow)
        addChild(label)
        
        setupArrow()
        setupLabel()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupArrow() {
        arrow.color = .white
        arrow.colorBlendFactor = 1.0
        
        arrow.position = CGPoint(
            x: 0,
            y: 0
        )
    }

    private func setupLabel() {
        label.fontName = "Baloo 2"
        label.fontSize = 52
        label.fontColor = .black
        
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        
        label.position = CGPoint(
            x: 0,
            y: 150
        )
    }
}
