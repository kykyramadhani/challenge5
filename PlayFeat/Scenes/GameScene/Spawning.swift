//
//  Spawning.swift
//  PlayFeat
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

        let plannedSize = size
        let steps = zip(toSpawn, scatterPoints(count: toSpawn.count)).map {
            ingredient,
            point in
            SKAction.sequence([
                .wait(forDuration: stagger),
                .run { [weak self] in
                    guard let self else { return }
                    // The board was resized while this one was still queued,
                    // so its planned spot belongs to the old size. Find it a
                    // free one on the board as it is now.
                    let spot = size == plannedSize
                        ? point
                        : scatterPoints(
                            count: 1,
                            avoiding: tableIngredients().map(\.position)
                        )[0]
                    popIn(ingredient, at: spot)
                },
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

    /// Random, non-overlapping positions for `count` bubbles in the spawn
    /// area, clear of the plate, the Reset button and the HUD.
    ///
    /// `avoiding` holds spots that are already taken but aren't being placed
    /// here — bubbles left floating while the plate is returned to the table.
    /// They constrain the placement without being handed back to the caller.
    func scatterPoints(count: Int, avoiding occupied: [CGPoint] = []) -> [CGPoint] {
        guard size.width > 0, size.height > 0 else {
            return Array(repeating: .zero, count: count)
        }
        var generator = SystemRandomNumberGenerator()
        let grid = spawnGrid(avoiding: occupied)
        // Only when the board can't fit them all apart, e.g. a phone in
        // landscape: an even grid where neighbours may touch beats no bubbles.
        return grid.positions(for: count, using: &generator)
            ?? gridPoints(count: count, in: grid.area)
    }

    /// Where bubble centres may go: the gameplay area between the plate and
    /// the HUD, inset so a bubble at the edge stays fully on screen.
    var bubbleSpawnArea: CGRect {
        let edgeGap = ingredientRadius + Self.bubbleScreenGap
        let minY = plateHome.y + plateRadius + ingredientRadius + Self.bubbleObstacleGap
        let maxY = size.height - hudExclusion - ingredientRadius - Self.bubbleObstacleGap
        // On a screen short enough that the plate's clearance runs past the
        // HUD's, the band collapses to a single line rather than inverting.
        return CGRect(
            x: edgeGap,
            y: minY,
            width: max(0, size.width - edgeGap * 2),
            height: max(0, maxY - minY)
        )
    }

    /// Space kept between a bubble and the screen edge.
    private static let bubbleScreenGap: CGFloat = 12

    /// Space kept between a bubble and the plate below or the HUD above.
    private static let bubbleObstacleGap: CGFloat = 30

    /// The board as SpawnGrid sees it: where bubbles may go, how far apart
    /// they must be, and what they must keep clear of.
    private func spawnGrid(avoiding occupied: [CGPoint]) -> SpawnGrid {
        // Room for the idle bob on both bubbles, so two neighbours floating
        // toward each other still never overlap. It sets the cell size.
        let floatRoom = ingredientRadius * IngredientNode.floatAmplitudeFraction * 2
        let spacing = ingredientRadius * 2 + floatRoom

        // How far a bubble reaches from its centre, bob included.
        let reach = ingredientRadius + floatRoom / 2

        var grid = SpawnGrid(area: bubbleSpawnArea, spacing: spacing)
        grid.blocked = boardObstacles.map { $0.insetBy(dx: -reach, dy: -reach) }
            + occupied.map { Self.square(around: $0, halfSide: spacing) }
        return grid
    }

    /// What no bubble may sit on: the plate, and the Reset button with its
    /// label. The band already keeps clear of both on every screen measured;
    /// checking them as well keeps that true if the layout changes.
    private var boardObstacles: [CGRect] {
        let plate = Self.square(around: plateHome, halfSide: plateRadius)
        let reset = resetNode?.calculateAccumulatedFrame()
        return [plate] + [reset].compactMap { $0 }
    }

    private static func square(around center: CGPoint, halfSide: CGFloat) -> CGRect {
        CGRect(
            x: center.x - halfSide,
            y: center.y - halfSide,
            width: halfSide * 2,
            height: halfSide * 2
        )
    }

    /// Deterministic grid fallback when the bubbles can't all fit apart.
    func gridPoints(count: Int, in area: CGRect) -> [CGPoint] {
        let columns = max(1, Int(area.width / (ingredientRadius * 1.2)) + 1)
        let rows = Int(ceil(Double(count) / Double(columns)))
        return (0..<count).map { index in
            let column = index % columns
            let row = index / columns
            let x = columns == 1
                ? area.minX
                : area.minX + area.width * CGFloat(column) / CGFloat(columns - 1)
            let y = rows == 1
                ? area.maxY
                : area.minY + area.height * CGFloat(row) / CGFloat(rows - 1)
            return CGPoint(x: x, y: y)
        }
    }
}
