//
//  GameScene+Serving.swift
//  GetCooking
//
//  Handles everything after a dish is complete: showing the finished dish
//  image, ringing the bell, carrying the plate off to it, plate discard
//  (reset hover), and committing/releasing ingredients.
//

import SpriteKit

extension GameScene {
    // MARK: - Finished dish

    /// Replaces the ingredient bubbles with the finished dish image
    /// on top of the plate.
    func showFinishedDish(_ recipe: Recipe) {
        ScuffleCloudAnimator.play(
            on: self,
            at: plateHome,
            width: plateRadius * 3
        )

        if let texture = TrimmedArt.texture(named: recipe.finishedDishImageName)
        {
            let dish = SKSpriteNode(texture: texture)
            dish.size = IngredientNode.aspectFit(
                texture.size(),
                into: plateRadius * 1.8
            )
            // A child of the plate, not of the scene: the player is about to
            // pick the plate up and carry it, and the meal has to travel with
            // it rather than stay behind at the table.
            dish.position = .zero
            dish.zPosition = 3
            dish.setScale(0)
            plateNode.addChild(dish)
            dish.run(.scale(to: 1, duration: 0.25))
            finishedDishNode = dish
        }
    }

    // MARK: - Bell

    /// Rings the bell in from one edge. That edge is where the player has to
    /// carry the plate to serve the dish.
    func showBell(on direction: SwipeDirection) {
        bellNode?.removeFromParent()

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

        let animation = BellAnimation.entrance(
            direction: direction,
            to: targetPosition
        )
        bell.run(animation)

        bellNode = bell
    }

    // MARK: - Serve animation

    /// Takes the plate the rest of the way off screen once it has been
    /// handed over at the bell, then brings out a fresh one and the next
    /// recipe's ingredients.
    ///
    /// The plate is already at the edge by this point — the player carried it
    /// there — so this only finishes the journey. The dish rides along as a
    /// child of the plate.
    func animateServe(direction: SwipeDirection, then nextRecipe: Recipe) {
        let slideX: CGFloat = direction == .left ? -size.width : size.width
        let slideOut = SKAction.moveBy(x: slideX, y: 0, duration: 0.35)
        slideOut.timingMode = .easeIn

        plateNode?.run(.sequence([slideOut, .removeFromParent()]))
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
    /// Drops an ingredient back onto the table, wherever the hand left it.
    ///
    /// Nothing is destroyed here. This button used to be a bin, and releasing
    /// over it deleted what you were holding — but it resets the plate now,
    /// and a control that quietly eats an ingredient you dragged across it is
    /// just a trap. `updateHandInput` keeps carried bubbles off it anyway.
    func releaseOntoTable(_ node: IngredientNode) {
        node.heldBy = nil
        node.zPosition = 2
    }

    /// Empties the plate by floating its contents back onto the table.
    ///
    /// Only the plate is affected: bubbles already floating stay exactly where
    /// they are, and the plated ones fly back out to free spots instead of
    /// being destroyed. Discarding used to bin the contents and respawn the
    /// whole board, which threw away a table the player had done nothing wrong
    /// with — the mistake only ever concerns the plate.
    func returnPlateContentsToTable() {
        let contents = plateIngredients()
        guard !contents.isEmpty else { return }

        // Land clear of the bubbles that are already out, so returning a plate
        // never stacks two ingredients on the same spot.
        let returning = Array(
            zip(
                contents.map(\.ingredient),
                scatterPoints(
                    count: contents.count,
                    avoiding: tableIngredients().map(\.position)
                )
            )
        )

        // Clear the plate first — each bubble shrinks away where it sat.
        for node in contents {
            node.removeAllActions()
            node.heldBy = nil
            node.run(.sequence([Self.bubbleVanish, .removeFromParent()]))
        }

        // Then they re-enter as fresh bubbles, through the same `popIn` a
        // spawned ingredient uses, so both arrivals look identical.
        run(
            .sequence([
                .wait(forDuration: Self.bubbleVanish.duration),
                .run { [weak self] in
                    for (ingredient, destination) in returning {
                        self?.popIn(ingredient, at: destination)
                    }
                },
            ]),
            withKey: returnActionKey
        )
    }

    /// All IngredientNodes currently sitting inside the plate container.
    func plateIngredients() -> [IngredientNode] {
        plateNode?.children.compactMap { $0 as? IngredientNode } ?? []
    }
}
