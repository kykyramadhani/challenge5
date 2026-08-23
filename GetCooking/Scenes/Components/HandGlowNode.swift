//
//  HandGlowNode.swift
//  GetCooking
//
//  The glowing aura drawn over each tracked hand, in place of the flat debug
//  dot that used to mark the cursor.
//
//  Built from soft radial sprites rather than a blur pass: one gradient
//  texture is rendered once and reused by every layer and every trail
//  particle, so the whole effect costs a handful of additively-blended
//  sprites and no per-frame filtering. Additive blending is what makes the
//  overlapping layers read as light rather than as stacked discs.
//

import SpriteKit
import UIKit

final class HandGlowNode: SKNode {

    /// Palm-sized core. Everything else is sized off this.
    private let radius: CGFloat

    private let halo: SKSpriteNode
    private let core: SKSpriteNode
    private let trail: SKEmitterNode

    /// The two house colours: accent while the hand is just being tracked,
    /// primary the moment it pinches. Green reads as "engaged", so it belongs
    /// on the active state rather than the idle one.
    static let openColor = UIColor(named: "AppAccent") ?? .orange
    static let grabColor = UIColor(named: "AppPrimary") ?? .green

    /// Enough to read as a continuous ribbon while the hand is moving, few
    /// enough that a still hand isn't sitting in a puddle of them.
    private static let trailBirthRate: CGFloat = 34

    init(radius: CGFloat = 46) {
        self.radius = radius

        let texture = Self.glowTexture

        halo = SKSpriteNode(texture: texture)
        core = SKSpriteNode(texture: texture)
        trail = Self.makeTrail(texture: texture, radius: radius)

        super.init()

        // Wide, faint outer bloom.
        halo.size = CGSize(width: radius * 4, height: radius * 4)
        halo.blendMode = .add
        halo.alpha = 0.5
        halo.colorBlendFactor = 1

        // Tight, bright centre — this is the bit that reads as the light
        // source sitting on the palm.
        core.size = CGSize(width: radius * 1.7, height: radius * 1.7)
        core.blendMode = .add
        core.alpha = 0.95
        core.colorBlendFactor = 1

        addChild(trail)
        addChild(halo)
        addChild(core)

        // A slow breath, so a hand held perfectly still still looks alive.
        halo.run(.repeatForever(.sequence([
            .group([.scale(to: 1.12, duration: 0.8), .fadeAlpha(to: 0.62, duration: 0.8)]),
            .group([.scale(to: 1.0, duration: 0.8), .fadeAlpha(to: 0.5, duration: 0.8)])
        ])))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Tints every layer for the hand's current pose.
    func setGrabbing(_ isGrabbing: Bool) {
        let colour = isGrabbing ? Self.grabColor : Self.openColor
        guard core.color != colour else { return }

        halo.color = colour
        core.color = colour
        trail.particleColor = colour

        // A quick flare on the change, so closing into a grab is felt rather
        // than just seen.
        core.removeAllActions()
        core.run(.sequence([
            .scale(to: isGrabbing ? 1.35 : 1.15, duration: 0.08),
            .scale(to: 1, duration: 0.16)
        ]))
    }

    /// The trail is emitted into the *scene*, not this node, so the particles
    /// stay where they were born instead of being dragged along — that is what
    /// turns movement into a wake of fading circles behind the hand.
    func attachTrail(to scene: SKScene) {
        trail.targetNode = scene
    }

    /// Shows or hides the whole glow.
    ///
    /// Not just `isHidden`: the trail's particles belong to the *scene* (see
    /// `attachTrail`), so they keep being drawn even while this node is
    /// hidden — a hand that goes away would leave a fountain running at the
    /// last place it was seen. Emission has to be stopped explicitly.
    func setVisible(_ visible: Bool) {
        isHidden = !visible
        trail.particleBirthRate = visible ? Self.trailBirthRate : 0
    }

    // MARK: - Shared art

    /// A soft white radial dot: opaque at the centre, transparent at the rim.
    ///
    /// Drawn once and shared by the halo, the core and every trail particle.
    /// Tinting happens per-sprite, so one texture covers both colours.
    private static let glowTexture: SKTexture = {
        let side: CGFloat = 128
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))

        let image = renderer.image { context in
            let centre = CGPoint(x: side / 2, y: side / 2)
            // Two inner stops rather than a straight white→clear ramp: it
            // holds a bright core before falling away, which is what gives the
            // dot a visible centre instead of a uniform smudge.
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor.white.cgColor,
                    UIColor.white.withAlphaComponent(0.65).cgColor,
                    UIColor.white.withAlphaComponent(0.18).cgColor,
                    UIColor.white.withAlphaComponent(0).cgColor
                ] as CFArray,
                locations: [0, 0.22, 0.55, 1]
            )!

            context.cgContext.drawRadialGradient(
                gradient,
                startCenter: centre, startRadius: 0,
                endCenter: centre, endRadius: side / 2,
                options: []
            )
        }

        return SKTexture(image: image)
    }()

    private static func makeTrail(texture: SKTexture, radius: CGFloat) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = texture
        emitter.particleBlendMode = .add

        emitter.particleBirthRate = trailBirthRate
        emitter.particleLifetime = 0.55
        emitter.particleLifetimeRange = 0.2

        emitter.particleSize = CGSize(width: radius * 1.25, height: radius * 1.25)
        emitter.particleScaleRange = 0.35
        // Shrinking as they fade is what makes the wake taper off behind the
        // hand rather than ending in a hard row of dots.
        emitter.particleScaleSpeed = -1.3

        emitter.particleAlpha = 0.55
        emitter.particleAlphaSpeed = -1.0

        emitter.particleColorBlendFactor = 1
        emitter.particleColor = openColor

        // Scattered around the palm instead of stacked on one point, so the
        // trail has some width to it.
        emitter.particlePositionRange = CGVector(dx: radius * 0.7, dy: radius * 0.7)

        return emitter
    }
}
