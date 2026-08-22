//
//  ResetButtonNode.swift
//  GetCooking
//
//  Created by Owen Limantoro on 13/08/26.
//

import SpriteKit
import SwiftUI

final class ResetButtonNode: SKNode {
    let resetRadius: CGFloat
    private let circle: SKShapeNode
    private let arrow: SKSpriteNode
    private let label: SKLabelNode

    init(radius: CGFloat) {
        self.resetRadius = radius
        
        // Circle
        circle = SKShapeNode(circleOfRadius: resetRadius)
        circle.fillColor = SKColor(.appText)
        circle.strokeColor = .clear
        
        // Arrow
        let config = UIImage.SymbolConfiguration(
            pointSize: 50,
            weight: .bold,
        )
        
        // TODO: FIX COLOR, it doesnt show in the game.
        
        guard let image = UIImage(
            systemName: "arrow.counterclockwise",
            withConfiguration: config
        )?.withTintColor(.appTertiary)
        else {
            fatalError("Could not load SF Symbol: arrow.counterclockwise")
        }

        
        arrow = SKSpriteNode(
            texture: SKTexture(image: image)
        )
        
        label = SKLabelNode()
         
        super.init()
        
        setupArrow()
        setupLabel()
        
        addChild(circle)
        addChild(arrow)
        addChild(label)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupLabel() {
        let text = "Reset"
        let fontName = "SFPro-Bold"
        let fontSize = resetRadius * 0.8
        let outlineWidth: CGFloat = 2.0   // outline thickness in points

        // 8 offset directions for an even outline
        let offsets: [CGPoint] = [
            CGPoint(x: -1, y: -1), CGPoint(x: 0, y: -1), CGPoint(x: 1, y: -1),
            CGPoint(x: -1, y:  0),                        CGPoint(x: 1, y:  0),
            CGPoint(x: -1, y:  1), CGPoint(x: 0, y:  1), CGPoint(x: 1, y:  1)
        ]

        // Black outline copies (behind)
        for offset in offsets {
            let outline = makeLabel(text, fontName: fontName, fontSize: fontSize, color: .black)
            outline.position = CGPoint(x: offset.x * outlineWidth,
                                       y: offset.y * outlineWidth)
            outline.zPosition = 0
            label.addChild(outline)
        }

        // Purple fill (on top)
        let fill = makeLabel(text, fontName: fontName, fontSize: fontSize, color: SKColor(.white))
        fill.zPosition = 1
        label.addChild(fill)

        label.position = CGPoint(x: 0, y: -resetRadius * 1.42)
    }

    private func makeLabel(_ text: String, fontName: String, fontSize: CGFloat, color: SKColor) -> SKLabelNode {
        let node = SKLabelNode(text: text)
        node.fontName = fontName
        node.fontSize = fontSize
        node.fontColor = color
        node.verticalAlignmentMode = .center
        node.horizontalAlignmentMode = .center
        return node
    }
 
    private func setupArrow() {
        arrow.position = .zero
    }
}
