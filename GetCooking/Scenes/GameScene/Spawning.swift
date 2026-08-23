//
//  GameScene+Spawning.swift
//  GetCooking
//
//  Creates ingredient bubbles and places them on the table.
//

import SpriteKit

extension GameScene {
    /// Spawns the recipe's required ingredients plus a couple of
    /// random decoys so the trash bin has a purpose.
    func spawnIngredientsIfNeeded(for recipe: Recipe) {
        guard spawnedRecipeName != recipe.name else { return }
        spawnedRecipeName = recipe.name
        clearTableIngredientNodes()
        
        // Getting Ingredients
        var toSpawn = recipe.ingredients
        let decoys = Ingredient.allCases
            .filter { !recipe.ingredients.contains($0) }
            .shuffled()
            .prefix(2)
        toSpawn.append(contentsOf: decoys)
        toSpawn.shuffle()

        // The board fills in faster the further the run has got — the manager
        // squeezes this off the same difficulty tier that tightens the dish
        // clock. Falls back to the scene's base when there's no manager
        // (previews / tests).
        let stagger = gameStateManager?.spawnStagger ?? spawnInterval

        let steps = zip(toSpawn, scatterPoints(count: toSpawn.count)).map {
            ingredient,
            point in
            SKAction.sequence([
                .wait(forDuration: stagger),
                .run { [weak self] in self?.popIn(ingredient, at: point) },
            ])
        }
        run(.sequence(steps), withKey: spawnActionKey)
    }

    /// The overshoot a bubble does as it settles, whether it was just spawned
    /// or has just floated back off the plate. Shared so the two entrances
    /// read as the same object arriving.
    static let bubbleSettle = SKAction.sequence([
        .scale(to: 1.15, duration: 0.2),
        .scale(to: 1.0, duration: 0.1),
    ])

    /// The mirror of `bubbleSettle`: a bubble shrinking away before it is
    /// replaced somewhere else. Callers time the replacement off this action's
    /// own `duration`, so the two can never drift apart.
    static let bubbleVanish = SKAction.group([
        .scale(to: 0, duration: 0.18),
        .fadeOut(withDuration: 0.18),
    ])

    /// Every ingredient loose on the table. The plate's own contents are
    /// children of `plateContainer`, so they are never in here.
    func tableIngredients() -> [IngredientNode] {
        children.compactMap { $0 as? IngredientNode }
    }

    /// Adds a single ingredient bubble with a pop-in animation.
    func popIn(_ ingredient: Ingredient, at point: CGPoint) {
        let node = IngredientNode(
            ingredient: ingredient,
            radius: ingredientRadius
        )
        node.position = point
        node.setScale(0)
        addChild(node)
        
        // Settle first, then start the idle bob. The completion never fires if
        // the bubble is grabbed mid-settle (grab calls removeAllActions), so a
        // held bubble can't wrongly start floating out of the hand.
        node.run(Self.bubbleSettle) { [weak node] in
            node?.startFloating()
        }
    }

    /// Removes every ingredient from the table and plate, and cancels
    /// any queued spawn actions.
    func clearTableIngredientNodes() {
        removeAction(forKey: spawnActionKey)
        removeAction(forKey: returnActionKey)
        tableIngredients().forEach { $0.removeFromParent() }
        plateIngredients().forEach { $0.removeFromParent() }
        abandonAllDrags()
    }

    /// Wipes the board for a brand-new game.
    func resetBoard() {
        clearTableIngredientNodes()
        finishedDishNode?.removeFromParent()
        finishedDishNode = nil
        bellNode?.removeFromParent()
        bellNode = nil
        spawnedRecipeName = nil
        trackers.removeAll()
        plateNode?.position = plateHome
    }

    // MARK: - Placement helpers

    /// Generates random non-overlapping positions for ingredient
    /// bubbles, keeping clear of the plate, trash bin, and HUD.
    ///
    /// `avoiding` holds spots that are already taken but aren't being placed
    /// here — bubbles left floating while the plate is returned to the table.
    /// They constrain the spacing without being handed back to the caller.
    func scatterPoints(count: Int, avoiding occupied: [CGPoint] = [])
        -> [CGPoint]
    {
        guard size.width > 0, size.height > 0 else {
            return Array(repeating: .zero, count: count)
        }

        let margin = ingredientRadius + 12

        // Reserve room for the idle bob on both bubbles, so two neighbours
        // floating toward each other still never overlap — the "box" each
        // bubble is given to move inside.
        let floatRoom = ingredientRadius * IngredientNode.floatAmplitudeFraction * 2
        let minDistanceBetweenPoints = ingredientRadius * 2 + floatRoom

        let xRange = margin...max(margin, size.width - margin)
        let spawnMinY =
            plateHome.y
            + plateRadius
            + ingredientRadius
            + 30

        let spawnMaxY =
            size.height
            - hudExclusion
            - ingredientRadius
            - 30

        let yRange = spawnMinY...spawnMaxY

        func attempt(spacing: CGFloat) -> [CGPoint]? {
            var points: [CGPoint] = []
            var tries = 0
            
            // 60 Tries Maximum
            while points.count < count && tries < count * 60 {
                tries += 1
                let candidate = CGPoint(
                    x: .random(in: xRange),
                    y: .random(in: yRange)
                )
                
                // Distance from Each Other
                guard
                    occupied.allSatisfy({
                        $0.vc_distance(to: candidate) > spacing
                    }),
                    
                    points.allSatisfy({
                        $0.vc_distance(to: candidate) > spacing
                    })
                else {
                    print("Hit Each other")
                    continue
                }
                
                points.append(candidate)
            }
            // On Average 30 Tries Total
            print("Total Tries: \(tries)")
            
            return points.count == count ? points : nil
        }
        
        // Generate the Minimum Spacing (Changing it each time to make it more scrambeled looking)
        for relaxation in [1.0, 0.95, 0.9] as [CGFloat] {
            if let points = attempt(
                spacing: minDistanceBetweenPoints * relaxation
            ) {
                return points
            }
        }
        
        return gridPoints(count: count, in: xRange, yRange: yRange)
    }

    /// Deterministic grid fallback when random placement fails.
    func gridPoints(
        count: Int,
        in xRange: ClosedRange<CGFloat>,
        yRange: ClosedRange<CGFloat>
    ) -> [CGPoint] {
        let columns = max(
            1,
            Int(
                (xRange.upperBound - xRange.lowerBound)
                    / (ingredientRadius * 1.2)
            ) + 1
        )
        
        let rows = Int(ceil(Double(count) / Double(columns)))
        return (0..<count).map { index in
            let column = index % columns
            let row = index / columns
            let x =
                columns == 1
                ? xRange.lowerBound
                : xRange.lowerBound + (xRange.upperBound - xRange.lowerBound)
                    * CGFloat(column) / CGFloat(columns - 1)
            let y =
                rows == 1
                ? yRange.upperBound
                : yRange.lowerBound + (yRange.upperBound - yRange.lowerBound)
                    * CGFloat(row) / CGFloat(rows - 1)
            return CGPoint(x: x, y: y)
        }
    }
}
