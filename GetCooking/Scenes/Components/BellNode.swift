//
//  BellNode.swift
//  GetCooking
//
//  The serving station: a tray with a bell sitting on top of it. Carrying the
//  finished plate here is how a dish is served.
//
//  The tray is what the player aims at — it is the big target and it has a
//  visible well for the plate to land in — while the bell is the thing that
//  catches the eye, shaking continuously so the station reads as "ringing for
//  service" rather than as scenery.
//

import SpriteKit

final class BellNode: SKNode {
    /// Overall footprint, tray included. The bell perches above this.
    let size: CGSize

    /// The recessed well drawn inside the tray art, as a fraction of the
    /// tray's own size. Measured off Tray.png — the plate has to shrink into
    /// *this*, not the full tray, or it overhangs the rim.
    private static let wellShare = CGSize(width: 0.82, height: 0.75)

    private let tray: SKSpriteNode
    private let bell: SKSpriteNode
    private let timer: TrayTimerNode

    /// Where a served plate comes to rest: the centre of the tray's well, in
    /// this node's own coordinates.
    var wellCentre: CGPoint { tray.position }

    /// How wide the well is, so the plate knows what to shrink to fit.
    var wellSize: CGSize {
        CGSize(width: size.width * Self.wellShare.width,
               height: size.height * Self.wellShare.height)
    }

    /// Tray.png's own aspect (1586 × 1211). Kept exactly, so the well stays
    /// where `wellShare` says it is.
    private static let trayAspect: CGFloat = 1211.0 / 1586.0

    /// RingingBell.png's own aspect (631 × 341).
    private static let bellAspect: CGFloat = 341.0 / 631.0

    /// Clear space between the bottom of the bell and the top of the tray.
    /// Fixed rather than proportional — it is a visual gap, and it should read
    /// the same whatever size the tray is scaled to.
    private static let bellGap: CGFloat = 11

    private static let ringingKey = "ringing"

    init(direction: SwipeDirection, width: CGFloat = 220) {
        size = CGSize(width: width, height: width * Self.trayAspect)

        tray = SKSpriteNode(imageNamed: "Tray")
        bell = SKSpriteNode(imageNamed: "RingingBell")
        timer = TrayTimerNode(radius: width * 0.15)

        super.init()

        tray.size = size
        tray.zPosition = 0

        // Centred on the tray, with `bellGap` of clear space between the two,
        // so the station reads as one object rather than a bell parked off to
        // one side. Clear of the well, so it never covers a served plate.
        let bellWidth = width * 0.42
        bell.size = CGSize(width: bellWidth, height: bellWidth * Self.bellAspect)
        bell.position = CGPoint(
            x: 0,
            y: size.height / 2 + Self.bellGap + bell.size.height / 2
        )
        bell.zPosition = 2

        // Sits in the well, where the plate will land — it is the empty tray
        // counting down, and the plate covers it on arrival.
        timer.position = wellCentre
        timer.zPosition = 1

        addChild(tray)
        addChild(timer)
        addChild(bell)

        bell.run(.repeatForever(BellAnimation.ringing), withKey: Self.ringingKey)
    }

    /// Draws the serve window on the tray's dial. `fraction` is time left.
    func updateTimer(fraction: CGFloat) {
        timer.update(fraction: fraction)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Settles a served plate into the tray's well.
    ///
    /// The plate is re-parented here rather than left in the scene, so it
    /// rides along with the tray — including the shake — instead of drifting
    /// out of a moving target.
    ///
    /// Position and scale are **snapped**, not animated. Re-parenting does not
    /// convert coordinates, so the plate's old scene-space position means
    /// something else entirely once it is a child of the tray; animating from
    /// there made the plate fly in from a direction unrelated to where the
    /// player actually dropped it. It is already at the tray in the player's
    /// eyes, so it should simply be there.
    func receive(_ plate: SKNode, shrunkTo scale: CGFloat) {
        plate.removeFromParent()
        plate.removeAllActions()
        plate.zPosition = 1
        plate.position = wellCentre
        plate.setScale(scale)
        addChild(plate)

        // The order is no longer waiting, so the dial goes with the ringing.
        timer.isHidden = true

        // The bell was ringing *for* this plate, so it falls quiet the moment
        // it arrives. Rocking is stopped and unwound rather than left where
        // the loop happened to be, or the bell would sit permanently tilted.
        bell.removeAction(forKey: Self.ringingKey)
        bell.run(.rotate(toAngle: 0, duration: 0.1))

        // One last thunk as it is struck.
        bell.run(BellAnimation.struck)
    }
}
