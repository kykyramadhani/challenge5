//
//  GameScene+Serving.swift
//  GetCooking
//
//  Handles everything after a dish is complete: showing the finished
//  dish image, the bell swipe cue, the plate slide-out animation,
//  plate discard (clap), and committing/releasing ingredients.
//

import SpriteKit

extension GameScene {

    // MARK: - Finished dish

    /// Replaces the ingredient bubbles with the finished dish image
    /// on top of the plate.
    func showFinishedDish(_ recipe: Recipe) {
        if let texture = TrimmedArt.texture(named: recipe.finishedDishImageName) {
            let dish = SKSpriteNode(texture: texture)
            dish.size = IngredientNode.aspectFit(texture.size(), into: plateRadius * 1.8)
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

        let container = SKNode()
        let bell = SKLabelNode(text: "🛎️")
        bell.fontSize = 50
        bell.verticalAlignmentMode = .center
        bell.horizontalAlignmentMode = .center
        container.addChild(bell)

        let xOffset: CGFloat = direction == .left ? -plateRadius - 60 : plateRadius + 60
        container.position = CGPoint(x: plateHome.x + xOffset, y: plateHome.y + plateRadius + 50)
        container.zPosition = 4
        container.setScale(0)
        addChild(container)

        container.run(.scale(to: 1, duration: 0.2))

        let nudge: CGFloat = direction == .left ? -14 : 14
        let ring = SKAction.sequence([
            .rotate(byAngle: 0.2, duration: 0.08),
            .rotate(byAngle: -0.4, duration: 0.16),
            .rotate(byAngle: 0.3, duration: 0.12),
            .rotate(byAngle: -0.1, duration: 0.08),
            .wait(forDuration: 0.5)
        ])
        let slide = SKAction.sequence([
            .moveBy(x: nudge, y: 0, duration: 0.4),
            .moveBy(x: -nudge, y: 0, duration: 0.4)
        ])
        slide.timingMode = .easeInEaseOut
        container.run(.repeatForever(.group([ring, slide])))
        swipeCueNode = container
    }

    // MARK: - Serve animation

    /// Slides the plate and finished dish off-screen in the swipe
    /// direction, then rebuilds a fresh plate and spawns the next
    /// recipe's ingredients.
    func animateServe(direction: SwipeDirection, then nextRecipe: Recipe) {
        let slideX: CGFloat = direction == .left ? -size.width : size.width
        let slideOut = SKAction.moveBy(x: slideX, y: 0, duration: 0.35)
        slideOut.timingMode = .easeIn

        let nodesToSlide = [plateContainer, finishedDishNode].compactMap { $0 }
        for node in nodesToSlide {
            node.run(.sequence([slideOut, .removeFromParent()]))
        }
        finishedDishNode = nil

        run(.sequence([
            .wait(forDuration: 0.4),
            .run { [weak self] in
                guard let self else { return }
                self.rebuildPlate()
                self.plateContainer.setScale(0)
                self.plateContainer.run(.scale(to: 1, duration: 0.2))
                self.spawnIngredientsIfNeeded(for: nextRecipe)
            }
        ]))
    }

    // MARK: - Plate interaction

    /// Moves an ingredient into the plate container. Called when the
    /// hand drags a bubble close enough to the bowl.
    func commitToPlate(_ node: IngredientNode, gameStateManager: GameStateManager) {
        node.heldBy = nil
        node.isOnPlate = true
        node.zPosition = 2
        node.removeFromParent()

        let scatter = plateRadius * 0.35
        node.position = CGPoint(x: .random(in: -scatter...scatter),
                                y: .random(in: -scatter...scatter))
        plateContainer.addChild(node)
        gameStateManager.addIngredientToPlate(node.ingredient)
    }

    /// Drops an ingredient back onto the table. If it lands on the
    /// trash bin, it's removed entirely.
    func releaseOntoTable(_ node: IngredientNode) {
        node.heldBy = nil
        node.zPosition = 2
        if node.position.vc_distance(to: trashNode.position) <= trashRadius + node.radius {
            node.removeFromParent()
        }
    }

    /// Flings the plate's contents outward when the player claps
    /// to discard, then respawns the same recipe's ingredients.
    func discardPlateContents(gameStateManager: GameStateManager) {
        let contents = plateIngredients()
        for (index, node) in contents.enumerated() {
            node.heldBy = nil
            node.removeAllActions()

            let angle = (CGFloat(index) / CGFloat(max(contents.count, 1))) * .pi * 2
                + .random(in: -0.3...0.3)
            let burst = plateRadius * 1.1
            let scatter = SKAction.group([
                .moveBy(x: cos(angle) * burst, y: sin(angle) * burst, duration: 0.18),
                .scale(to: 1.25, duration: 0.18)
            ])
            scatter.timingMode = .easeOut

            let fallDistance = plateHome.y + ingredientRadius + 160
            let fall = SKAction.group([
                .moveBy(x: cos(angle) * 40, y: -fallDistance, duration: 0.5),
                .rotate(byAngle: .random(in: -2.2...2.2), duration: 0.5),
                .fadeOut(withDuration: 0.5)
            ])
            fall.timingMode = .easeIn

            node.run(.sequence([scatter, fall, .removeFromParent()]))
        }

        spawnedRecipeName = nil
        spawnIngredientsIfNeeded(for: gameStateManager.currentRecipe)
    }

    /// All IngredientNodes currently sitting inside the plate container.
    func plateIngredients() -> [IngredientNode] {
        plateContainer?.children.compactMap { $0 as? IngredientNode } ?? []
    }
}
