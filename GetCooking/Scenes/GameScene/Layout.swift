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

        let reset = ResetButtonNode()
        addChild(reset)
        resetNode = reset

        // Above the plate and the bubbles, so a dish sitting on the plate
        // never hides how much time is left on it.
        let dishTimer = DishTimerNode(radius: dishTimerRadius)
        dishTimer.zPosition = 5
        addChild(dishTimer)
        dishTimerNode = dishTimer

        layoutStaticNodes()
    }

    /// Re-sizes and re-positions everything after a rotation or size change.
    func layoutStaticNodes() {
        guard size.width > 0, size.height > 0 else { return }

        plateNode?.position = plateHome

        dishTimerNode?.position = dishTimerHome
        dishTimerNode?.resize(to: dishTimerRadius)

        // Reset button
        let inset: CGFloat = 120
        resetNode?.position = CGPoint(
            x: size.width - inset,
            y: inset
        )
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
    }
}
