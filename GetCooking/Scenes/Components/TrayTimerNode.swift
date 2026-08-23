//
//  TrayTimerNode.swift
//  GetCooking
//
//  The dial on the serving tray: how long the order will wait before it is
//  abandoned.
//
//  Drawn as a white disc that fills with red as the window runs out, with a
//  white ring left on top. The ring is what keeps the dial legible once the
//  red has eaten the whole face — without it a spent timer is just a red blob
//  on an orange tray.
//

import SpriteKit

final class TrayTimerNode: SKNode {

    private let radius: CGFloat

    /// White face, drawn under everything.
    private let face: SKShapeNode
    /// The spent slice, sweeping clockwise from 12 o'clock.
    private let spent: SKShapeNode
    /// White outline, drawn over the slice so it survives a full sweep.
    private let ring: SKShapeNode

    init(radius: CGFloat) {
        self.radius = radius

        face = SKShapeNode(circleOfRadius: radius)
        spent = SKShapeNode()
        ring = SKShapeNode(circleOfRadius: radius)

        super.init()

        face.fillColor = .white
        face.strokeColor = .clear
        face.zPosition = 0

        spent.fillColor = .systemRed
        spent.strokeColor = .clear
        spent.zPosition = 1

        ring.fillColor = .clear
        ring.strokeColor = .white
        ring.lineWidth = max(3, radius * 0.16)
        ring.zPosition = 2

        addChild(face)
        addChild(spent)
        addChild(ring)

        update(fraction: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// `fraction` is how much time is **left**, 1 down to 0.
    func update(fraction: CGFloat) {
        spent.path = Self.wedgePath(radius: radius, fraction: 1 - fraction)
    }

    /// The spent slice: a pie wedge of `fraction` of the disc, sweeping
    /// clockwise from 12 o'clock — the direction a clock's hand travels, so
    /// the red reads as time being eaten rather than as an arbitrary shape.
    ///
    /// A `static func` so the geometry can be checked without a live scene.
    static func wedgePath(radius: CGFloat, fraction: CGFloat) -> CGPath {
        let sweep = fraction.vc_clamped(to: 0...1)
        guard sweep > 0 else { return CGMutablePath() }

        let path = CGMutablePath()
        path.move(to: .zero)
        // SpriteKit is y-up, so 12 o'clock is +π/2 and clockwise means the
        // angle decreasing from there.
        path.addArc(
            center: .zero,
            radius: radius,
            startAngle: .pi / 2,
            endAngle: .pi / 2 - .pi * 2 * sweep,
            clockwise: true
        )
        path.closeSubpath()

        return path
    }
}
