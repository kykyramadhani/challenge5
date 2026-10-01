//
//  ScuffleCloudAnimator.swift
//  GetCooking
//
//  Plays the scuffle-cloud frame animation over a given position in
//  a SpriteKit scene. Loads the loose PNGs from
//  Resources/Animation/ScuffleCloud/ (1.png – 4.png).
//

import SpriteKit
import UIKit

struct ScuffleCloudAnimator {
    private static let frameCount = 4

    private static func loadFrames() -> [SKTexture] {
        (1...frameCount).compactMap { index in
            guard let url = Bundle.main.url(
                forResource: "\(index)", withExtension: "png"
            ) else { return nil }
            guard let image = UIImage(contentsOfFile: url.path) else { return nil }
            return SKTexture(image: image)
        }
    }

    static func play(on parent: SKNode, at position: CGPoint, width: CGFloat) {
        let frames = loadFrames()
        guard let first = frames.first else { return }

        let aspect = first.size().height / first.size().width
        let sprite = SKSpriteNode(texture: first)
        sprite.size = CGSize(width: width, height: width * aspect)
        sprite.position = position
        sprite.zPosition = 50
        sprite.setScale(0)
        parent.addChild(sprite)

        let appear = SKAction.scale(to: 1.0, duration: 0.1)
        appear.timingMode = .easeOut
        let animate = SKAction.animate(with: frames, timePerFrame: 0.12)
        let loop = SKAction.repeat(animate, count: 1)
        let disappear = SKAction.fadeOut(withDuration: 0.2)

        sprite.run(.sequence([appear, loop, disappear, .removeFromParent()]))
    }
}
