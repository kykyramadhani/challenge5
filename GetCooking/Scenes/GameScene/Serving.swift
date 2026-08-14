//
//  GameScene+Serving.swift
//  GetCooking
//
//  Handles everything after a dish is complete: showing the finished
//  dish image, the bell swipe cue, the plate slide-out animation,
//  plate discard (trash hover), and committing/releasing ingredients.
//

import SpriteKit

extension GameScene {
    // MARK: - Finished dish

    /// Replaces the ingredient bubbles with the finished dish image
    /// on top of the plate.
    func showFinishedDish(_ recipe: Recipe) {
        if let texture = TrimmedArt.texture(named: recipe.finishedDishImageName)
        {
            let dish = SKSpriteNode(texture: texture)
            dish.size = IngredientNode.aspectFit(
                texture.size(),
                into: plateRadius * 1.8
            )
            dish.position = plateHome
            dish.zPosition = 3
            dish.setScale(0)
            addChild(dish)
            dish.run(.scale(to: 1, duration: 0.25))
            finishedDishNode = dish
        }
    }

    // MARK: - Bell swipe cue
    /// Shows a ringing bell that nudges toward the serve direction,
    /// telling the player which way to swipe.
    func showSwipeCue(direction: SwipeDirection) {
        swipeCueNode?.removeFromParent()

        let bell = BellNode(direction: direction)

        let targetX: CGFloat
        let startX: CGFloat

        if direction == .left {
            // Final position
            targetX = bell.size.width / 2
            
            // Start outside the left edge
            startX = -bell.size.width / 2
        } else {
            // Final position
            targetX = size.width - bell.size.width / 2
            
            // Start outside the right edge
            startX = size.width + bell.size.width / 2
        }

        let targetPosition = CGPoint(
            x: targetX,
            y: size.height / 2
        )

        bell.position = CGPoint(
            x: startX,
            y: targetPosition.y
        )

        bell.zPosition = 4
        addChild(bell)

        let animation = BellAnimation.entrance(direction: direction, to: targetPosition)
        bell.run(animation)
        
        swipeCueNode = bell
    }

    // MARK: - Serve animation

    /// Slides the plate and finished dish off-screen in the swipe
    /// direction, then rebuilds a fresh plate and spawns the next
    /// recipe's ingredients.
    func animateServe(direction: SwipeDirection, then nextRecipe: Recipe) {
        let slideX: CGFloat = direction == .left ? -size.width : size.width
        let slideOut = SKAction.moveBy(x: slideX, y: 0, duration: 0.35)
        slideOut.timingMode = .easeIn

        let nodesToSlide = [plateNode, finishedDishNode].compactMap { $0 }
        for node in nodesToSlide {
            node.run(.sequence([slideOut, .removeFromParent()]))
        }
        finishedDishNode = nil

        run(
            .sequence([
                .wait(forDuration: 0.4),
                .run { [weak self] in
                    guard let self else { return }
                    self.rebuildPlate()
                    self.plateNode.setScale(0)
                    self.plateNode.run(.scale(to: 1, duration: 0.7))
                    self.spawnIngredientsIfNeeded(for: nextRecipe)
                },
            ])
        )
    }

    // MARK: - Plate interaction

    /// Moves an ingredient into the plate container. Called when the
    /// hand drags a bubble close enough to the bowl.
    func commitToPlate(
        _ node: IngredientNode,
        gameStateManager: GameStateManager
    ) {
        node.heldBy = nil
        node.isOnPlate = true
        node.zPosition = 2
        node.removeFromParent()

        let scatter = plateRadius * 0.35
        node.position = CGPoint(
            x: .random(in: -scatter...scatter),
            y: .random(in: -scatter...scatter)
        )
        plateNode.addChild(node)
        gameStateManager.addIngredientToPlate(node.ingredient)
    }

    /// Drops an ingredient back onto the table. If it lands on the
    /// trash bin, it's removed entirely.
    func releaseOntoTable(_ node: IngredientNode) {
        node.heldBy = nil
        node.zPosition = 2
        if node.position.vc_distance(to: resetNode.position) <= resetRadius
            + node.radius
        {
            node.removeFromParent()
        }
    }

    /// Flings the plate's contents outward when the player holds a hand over
    /// the bin to discard, then respawns the same recipe's ingredients.
    func discardPlateContents(gameStateManager: GameStateManager) {
        let contents = plateIngredients()
        for (index, node) in contents.enumerated() {
            node.heldBy = nil
            node.removeAllActions()

            let angle =
                (CGFloat(index) / CGFloat(max(contents.count, 1))) * .pi * 2
                + .random(in: -0.3...0.3)
            let burst = plateRadius * 1.1
            let scatter = SKAction.group([
                .moveBy(
                    x: cos(angle) * burst,
                    y: sin(angle) * burst,
                    duration: 0.18
                ),
                .scale(to: 1.25, duration: 0.18),
            ])
            scatter.timingMode = .easeOut

            let fallDistance = plateHome.y + ingredientRadius + 160
            let fall = SKAction.group([
                .moveBy(x: cos(angle) * 40, y: -fallDistance, duration: 0.5),
                .rotate(byAngle: .random(in: -2.2...2.2), duration: 0.5),
                .fadeOut(withDuration: 0.5),
            ])
            fall.timingMode = .easeIn

            node.run(.sequence([scatter, fall, .removeFromParent()]))
        }

        spawnedRecipeName = nil
        spawnIngredientsIfNeeded(for: gameStateManager.currentRecipe)
    }

    /// All IngredientNodes currently sitting inside the plate container.
    func plateIngredients() -> [IngredientNode] {
        plateNode?.children.compactMap { $0 as? IngredientNode } ?? []
    }
}
