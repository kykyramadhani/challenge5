//
//  GameScene+Layout.swift
//  GetCooking
//
//  Creates and positions the plate and trash bin.
//

import SpriteKit

extension GameScene {
    /// One-time setup: creates the plate container and trash bin.
    func buildStaticNodes() {
        let plate = PlateNode(radius: plateRadius)
        plate.zPosition = 1
        addChild(plate)
        plateNode = plate

        let reset = ResetButtonNode(radius: resetRadius)
        addChild(reset)
        resetNode = reset

        applyBoardVisibility()
        layoutStaticNodes()
    }

    /// Shows or hides the playfield furniture. Called whenever `showsBoard`
    /// changes and again whenever a node is rebuilt, so a plate created mid-run
    /// inherits the current setting rather than defaulting to visible.
    func applyBoardVisibility() {
        plateNode?.isHidden = !showsBoard
        resetNode?.isHidden = !showsBoard
    }

    /// Re-sizes and re-positions everything after a rotation or size change.
    func layoutStaticNodes() {
        guard size.width > 0, size.height > 0 else { return }

        plateNode?.position = plateHome

        // Reset button. Canvas points, like the radii, so it tucks into the
        // corner by the same proportion on an iPad mini as on a 13".
        let inset: CGFloat = 120 * designScale
        resetNode?.position = CGPoint(
            x: size.width - inset,
            y: inset
        )
    }

    /// Moves the loose bubbles onto the board as it is now.
    ///
    /// Their spots were picked for the old size, so after a rotation or a
    /// Split View resize they could sit off the edge or under the HUD — a
    /// recipe ingredient off-screen is a dish that can never be finished.
    /// Bubbles in a hand stay put; the rest are kept clear of them.
    ///
    /// Each bubble jumps straight to its new spot and re-settles there, rather
    /// than gliding: a bubble still queued to spawn picks its spot clear of
    /// the live positions, and a glide would leave those pointing at where
    /// bubbles *were*. Never removed either, so a reaching hand still finds it.
    /// ponytail: positions only. Radii stay as spawned, which is exact for a
    /// rotation (same short edge) and only approximate after a window resize.
    func rescatterTableIngredients() {
        let table = tableIngredients()
        let loose = table.filter { $0.heldBy == nil }
        guard !loose.isEmpty else { return }

        let spots = scatterPoints(
            count: loose.count,
            avoiding: table.filter { $0.heldBy != nil }.map(\.position)
        )

        for (node, spot) in zip(loose, spots) {
            node.removeAllActions()
            node.position = spot
            node.setScale(0.6)
            node.run(Self.bubbleSettle) { [weak node] in node?.startFloating() }
        }
    }

    /// Tears down the old plate container and creates a fresh one.
    /// Used after the serve animation slides the plate off-screen.
    func rebuildPlate() {
        plateNode?.removeFromParent()
        
        let plate = PlateNode(radius: plateRadius)
        plate.zPosition = 1
        plate.position = plateHome

        addChild(plate)
        plateNode = plate
        applyBoardVisibility()
    }
}
