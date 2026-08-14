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

        var toSpawn = recipe.ingredients
        let decoys = Ingredient.allCases
            .filter { !recipe.ingredients.contains($0) }
            .shuffled()
            .prefix(2)
        toSpawn.append(contentsOf: decoys)
        toSpawn.shuffle()

        let steps = zip(toSpawn, scatterPoints(count: toSpawn.count)).map { ingredient, point in
            SKAction.sequence([
                .wait(forDuration: spawnInterval),
                .run { [weak self] in self?.popIn(ingredient, at: point) }
            ])
        }
        run(.sequence(steps), withKey: spawnActionKey)
    }

    /// The overshoot a bubble does as it settles, whether it was just spawned
    /// or has just floated back off the plate. Shared so the two entrances
    /// read as the same object arriving.
    static let bubbleSettle = SKAction.sequence([
        .scale(to: 1.15, duration: 0.18),
        .scale(to: 1.0, duration: 0.08)
    ])

    /// The mirror of `bubbleSettle`: a bubble shrinking away before it is
    /// replaced somewhere else. Callers time the replacement off this action's
    /// own `duration`, so the two can never drift apart.
    static let bubbleVanish = SKAction.group([
        .scale(to: 0, duration: 0.18),
        .fadeOut(withDuration: 0.18)
    ])

    /// Every ingredient loose on the table. The plate's own contents are
    /// children of `plateContainer`, so they are never in here.
    func tableIngredients() -> [IngredientNode] {
        children.compactMap { $0 as? IngredientNode }
    }

    /// Adds a single ingredient bubble with a pop-in animation.
    func popIn(_ ingredient: Ingredient, at point: CGPoint) {
        let node = IngredientNode(ingredient: ingredient, radius: ingredientRadius)
        node.position = point
        node.setScale(0)
        addChild(node)
        node.run(Self.bubbleSettle)
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
        swipeCueNode?.removeFromParent()
        swipeCueNode = nil
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
    func scatterPoints(count: Int, avoiding occupied: [CGPoint] = []) -> [CGPoint] {
        guard size.width > 0, size.height > 0 else {
            return Array(repeating: .zero, count: count)
        }

        let margin = ingredientRadius + 12
        let topExclusion = max(170, size.height * 0.16)
        let minDistanceFromPlate = plateRadius + ingredientRadius * 0.8
        let minDistanceBetweenPoints = ingredientRadius * 1.5

        let xRange = margin...max(margin, size.width - margin)
        let yRange = margin...max(margin, size.height - topExclusion)

        func attempt(spacing: CGFloat) -> [CGPoint]? {
            var points: [CGPoint] = []
            var tries = 0
            while points.count < count && tries < count * 60 {
                tries += 1
                let candidate = CGPoint(x: .random(in: xRange), y: .random(in: yRange))
                guard candidate.vc_distance(to: plateHome) > minDistanceFromPlate else { continue }
                guard candidate.vc_distance(to: resetNode.position) > resetRadius + ingredientRadius else { continue }
                guard occupied.allSatisfy({ $0.vc_distance(to: candidate) > spacing }),
                      points.allSatisfy({ $0.vc_distance(to: candidate) > spacing })
                else { continue }
                points.append(candidate)
            }
            return points.count == count ? points : nil
        }

        for relaxation in [1.0, 0.8, 0.65, 0.5] as [CGFloat] {
            if let points = attempt(spacing: minDistanceBetweenPoints * relaxation) {
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
        let columns = max(1, Int((xRange.upperBound - xRange.lowerBound) / (ingredientRadius * 1.2)) + 1)
        let rows = Int(ceil(Double(count) / Double(columns)))
        return (0..<count).map { index in
            let column = index % columns, row = index / columns
            let x = columns == 1
                ? xRange.lowerBound
                : xRange.lowerBound + (xRange.upperBound - xRange.lowerBound) * CGFloat(column) / CGFloat(columns - 1)
            let y = rows == 1
                ? yRange.upperBound
                : yRange.lowerBound + (yRange.upperBound - yRange.lowerBound) * CGFloat(row) / CGFloat(rows - 1)
            return CGPoint(x: x, y: y)
        }
    }
}
