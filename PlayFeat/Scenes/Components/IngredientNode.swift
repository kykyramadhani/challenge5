//
//  IngredientNode.swift
//  GetCooking
//
//  Created by Owen Limantoro on 12/08/26.
//

import SpriteKit
import SwiftUI

final class IngredientNode: SKNode {
    let ingredient: Ingredient

    /// Whether this ingredient is sitting in the plate.
    ///
    /// Setting it hides the bubble shell — once plated the ingredient should
    /// read as food on a plate, not as something still floating and grabbable.
    /// Hidden rather than removed so the node survives going back to the table.
    var isOnPlate = false {
        didSet { bubble?.isHidden = isOnPlate }
    }

    /// `HandData.id` of the hand currently holding this, so the other hand
    /// can't grab the same bubble out from under it.
    var heldBy: Int?

    /// Radius of the bubble. Set by the scene from the screen size — hand
    /// tracking is far too jittery for a small target to be grabbable.
    let radius: CGFloat

    /// The glassy shell drawn over the food. Nil only if the art is missing.
    private var bubble: SKSpriteNode?

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
            food.size = Self.aspectFit(
                texture.size(),
                into: radius * 2 * Self.contentFill
            )
            food.zPosition = 0
            addChild(food)
        }

        // Front: the bubble, drawn over the food so it looks encased.
        if let bubbleTexture = TrimmedArt.texture(named: GameArt.bubble) {
            let bubble = SKSpriteNode(texture: bubbleTexture)
            bubble.size = Self.aspectFit(bubbleTexture.size(), into: radius * 2)
            bubble.zPosition = 1
            addChild(bubble)
            self.bubble = bubble
        }

        zPosition = 2
    }

    /// Scales `size` so its longest edge is `maxDimension`, preserving the
    /// aspect ratio. Squashing art into a square would turn the bubble into
    /// an ellipse.
    static func aspectFit(_ size: CGSize, into maxDimension: CGFloat) -> CGSize
    {
        guard size.width > 0, size.height > 0 else {
            return CGSize(width: maxDimension, height: maxDimension)
        }
        let scale = maxDimension / max(size.width, size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Idle float

    /// The furthest the idle bob ever carries the bubble from its resting spot,
    /// as a fraction of the radius. `scatterPoints` widens the spacing between
    /// bubbles by this much, so two neighbours bobbing toward one another still
    /// never touch — this fraction *is* the "box" each bubble floats inside.
    static let floatAmplitudeFraction: CGFloat = 0.14

    /// Key so the bob can be started, stopped and restarted without disturbing
    /// the pop-in/settle actions that also run on this node.
    private static let floatKey = "idleFloat"

    /// Bobs the bubble gently up and down in place, so a table of them reads as
    /// buoyant instead of pinned to the board.
    ///
    /// Purely cosmetic, but the node's `position` really does move — grab
    /// detection reads that live position, so a bobbing bubble is still grabbed
    /// exactly where the player sees it. The drift stays inside the room
    /// `scatterPoints` reserves for it, capped at `floatAmplitudeFraction` of
    /// the radius.
    ///
    /// Each bubble picks its own period and a random starting phase, so a whole
    /// table looks independently afloat rather than bobbing in lockstep.
    func startFloating() {
        // Don't stack a second oscillation if one is already running.
        guard action(forKey: Self.floatKey) == nil else { return }

        let amplitude =
            radius * Self.floatAmplitudeFraction * CGFloat.random(in: 0.8...1.0)
        let half = TimeInterval.random(in: 1.1...1.6)

        let up = SKAction.moveBy(x: 0, y: amplitude, duration: half)
        up.timingMode = .easeInEaseOut
        
        // `reversed()` returns exactly to the start, so the bob stays anchored
        // to the resting spot every cycle instead of walking away from it.
        let bob = SKAction.repeatForever(.sequence([up, up.reversed()]))

        // A random head start so they don't all crest at the same instant.
        // Only the *start* is delayed; the loop itself stays anchored.
        let phase = SKAction.wait(forDuration: .random(in: 0...(half * 1.5)))
        run(.sequence([phase, bob]), withKey: Self.floatKey)
    }

    /// Stops the idle bob and leaves the node where it is — a grab or a plate
    /// hand-off owns positioning from here.
    func stopFloating() {
        removeAction(forKey: Self.floatKey)
    }
}
