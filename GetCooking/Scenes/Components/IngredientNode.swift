//
//  IngredientNode.swift
//  GetCooking
//
//  Created by Owen Limantoro on 12/08/26.
//

import SwiftUI
import SpriteKit

final class IngredientNode: SKNode {
    let ingredient: Ingredient
    var isOnPlate = false
    /// `HandData.id` of the hand currently holding this, so the other hand
    /// can't grab the same bubble out from under it.
    var heldBy: Int?

    /// Radius of the bubble. Set by the scene from the screen size — hand
    /// tracking is far too jittery for a small target to be grabbable.
    let radius: CGFloat

    /// How much of the bubble's width the food is allowed to fill. Kept under
    /// 1 so the art sits inside the glassy rim instead of overrunning it.
    private static let contentFill: CGFloat = 0.62

    init(ingredient: Ingredient, radius: CGFloat) {
        self.ingredient = ingredient
        self.radius = radius
        super.init()

        // Back: the food itself.
        if let texture = TrimmedArt.texture(named: ingredient.imageName) {
            let food = SKSpriteNode(texture: texture)
            food.size = Self.aspectFit(texture.size(), into: radius * 2 * Self.contentFill)
            food.zPosition = 0
            addChild(food)
        }

        // Front: the bubble, drawn over the food so it looks encased.
        if let bubbleTexture = TrimmedArt.texture(named: GameArt.bubble) {
            let bubble = SKSpriteNode(texture: bubbleTexture)
            bubble.size = Self.aspectFit(bubbleTexture.size(), into: radius * 2)
            bubble.zPosition = 1
            addChild(bubble)
        }

        zPosition = 2
    }

    /// Scales `size` so its longest edge is `maxDimension`, preserving the
    /// aspect ratio. Squashing art into a square would turn the bubble into
    /// an ellipse.
    static func aspectFit(_ size: CGSize, into maxDimension: CGFloat) -> CGSize {
        guard size.width > 0, size.height > 0 else {
            return CGSize(width: maxDimension, height: maxDimension)
        }
        let scale = maxDimension / max(size.width, size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
