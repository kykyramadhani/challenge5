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
    private let button: SKSpriteNode
    private let label: SKLabelNode

    init(radius: CGFloat) {
        self.resetRadius = radius

        // Button artwork from Assets.xcassets ("ResetButton") instead of a
        // drawn circle + SF Symbol arrow. Sized to the same footprint the old
        // circle had — width = 2 × resetRadius — so hit-testing and layout that
        // key off `resetRadius` are unaffected. The height follows the image's
        // own aspect ratio so it never looks squashed.
        let texture = SKTexture(imageNamed: "ResetButton")
        button = SKSpriteNode(texture: texture)

        let targetWidth = resetRadius * 2
        let aspect = texture.size().height / max(texture.size().width, 1)
        button.size = CGSize(width: targetWidth, height: targetWidth * aspect)

        label = SKLabelNode()

        super.init()

        button.position = .zero
        setupLabel()

        addChild(button)
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
}
