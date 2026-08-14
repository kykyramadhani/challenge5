//
//  DishTimerNode.swift
//  GetCooking
//
//  The countdown pie beside the plate: how much of the current dish's
//  assembly clock is left before it costs a life.
//

import SpriteKit

final class DishTimerNode: SKNode {

    /// #FF7F5C.
    static let tint = SKColor(
        red: 0xFF / 255, green: 0x7F / 255, blue: 0x5C / 255, alpha: 1
    )

    /// Rim thickness, in points.
    static let rimWidth: CGFloat = 5

    /// White disc with a tinted rim, sitting behind the wedge.
    ///
    /// Without it the spent part of the clock would be a hole onto the camera
    /// feed, which reads as the timer disappearing rather than emptying. The
    /// rim also keeps the full extent visible once the wedge is nearly gone.
    private let dial = SKShapeNode()

    /// The remaining time, drawn over the dial.
    private let wedge = SKShapeNode()

    private var radius: CGFloat

    /// Fraction of the clock still left, 1...0.
    private var fraction: CGFloat = 1

    init(radius: CGFloat) {
        self.radius = radius
        super.init()

        dial.fillColor = .white
        dial.strokeColor = Self.tint
        dial.lineWidth = Self.rimWidth
        dial.zPosition = 0
        addChild(dial)

        wedge.fillColor = Self.tint
        wedge.strokeColor = .clear
        wedge.zPosition = 1
        addChild(wedge)

        redrawDial()
        redrawWedge()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Sets how much time is left. Called every frame, so it redraws only when
    /// the wedge would actually move — rebuilding a `CGPath` 60 times a second
    /// to produce the same shape is pure waste.
    func update(fraction: CGFloat) {
        let next = fraction.vc_clamped(to: 0...1)
        guard abs(next - self.fraction) > 0.001 else { return }
        self.fraction = next
        redrawWedge()
    }

    /// Rebuilds at a new size after a rotation or window resize.
    func resize(to radius: CGFloat) {
        guard radius != self.radius else { return }
        self.radius = radius
        redrawDial()
        redrawWedge()
    }

    /// Separate from `redrawWedge` because the dial only changes with the
    /// radius, and that is not something the countdown touches.
    private func redrawDial() {
        dial.path = CGPath(
            ellipseIn: CGRect(
                x: -radius, y: -radius, width: radius * 2, height: radius * 2
            ),
            transform: nil
        )
    }

    private func redrawWedge() {
        wedge.path = Self.wedgePath(radius: radius, fraction: fraction)
    }

    /// The slice still to run, as a closed wedge centred on the origin.
    ///
    /// Pulled out as a `static func` so the angles can be checked without a
    /// live SpriteKit view — the start angle and the sweep direction are the
    /// two things here that are easy to get backwards.
    static func wedgePath(radius: CGFloat, fraction: CGFloat) -> CGPath {
        let top = CGFloat.pi / 2
        let full = CGFloat.pi * 2

        // The spent slice is eaten away clockwise from 12 o'clock, so whatever
        // is left always ends back at the top.
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addArc(
            center: .zero,
            radius: radius,
            startAngle: top - (1 - fraction) * full,
            endAngle: top - full,
            clockwise: true
        )
        path.closeSubpath()

        return path
    }
}
