//
//  BellAnimation.swift
//  GetCooking
//
//  Created by Owen Limantoro on 14/08/26.
//

import SpriteKit

enum BellAnimation {
    static func entrance(
        direction: SwipeDirection,
        to targetPosition: CGPoint
    ) -> SKAction {

        let slideIn = SKAction.move(
            to: targetPosition,
            duration: 0.5
        )

        slideIn.timingMode = .easeOut

        let bounce = SKAction.sequence([
            .moveBy(
                x: direction == .left ? 8 : -8,
                y: 0,
                duration: 0.08
            ),
            .moveBy(
                x: direction == .left ? -8 : 8,
                y: 0,
                duration: 0.08
            )
        ])

        return .sequence([
            slideIn,
            bounce
        ])
    }
}
