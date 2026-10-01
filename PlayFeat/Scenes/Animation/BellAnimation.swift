//
//  BellAnimation.swift
//  GetCooking
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

    /// The bell's shake, run on repeat from the moment the station appears
    /// until the plate lands on it.
    ///
    /// A rotation rather than a translation: a bell rocks on its base, and
    /// swinging it sideways reads as the whole thing sliding instead.
    ///
    /// Deliberately unbroken — no rest between peals. The bell is what tells
    /// the player an order is waiting, and one that goes quiet every second
    /// reads as decoration rather than as something demanding attention. It
    /// only stops when the dish is actually delivered.
    static var ringing: SKAction {
        let angle: CGFloat = .pi / 20

        return .sequence([
            .rotate(toAngle: angle, duration: 0.07),
            .rotate(toAngle: -angle, duration: 0.07)
        ])
    }

    /// One sharp knock, for the moment a plate actually lands on the tray.
    static var struck: SKAction {
        .sequence([
            .scale(to: 1.25, duration: 0.08),
            .scale(to: 1, duration: 0.12)
        ])
    }
}
