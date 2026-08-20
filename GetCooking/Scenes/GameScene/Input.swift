//
//  GameScene+HandInput.swift
//  GetCooking
//
//  Reads hand-pose data every frame and turns it into grab, drag,
//  release, and trash-hover interactions.
//

import SpriteKit

extension GameScene {

    /// A snapshot of one hand this frame, in scene coordinates.
    struct FrameHand {
        let cursor: CGPoint
        let isOpen: Bool
        let isHolding: Bool
    }

    // MARK: - Per-frame hand processing

    /// Reads every tracked hand, converts its joints from view space
    /// (top-left origin, y-down) to scene space (bottom-left, y-up),
    /// and runs the grab / drag / release / trash-hover logic.
    func updateHandInput(now: TimeInterval, delta: TimeInterval = 0) {
        // Hands are live for two phases now: cooking, where they move
        // ingredients, and serving, where they carry the whole plate to the
        // bell. Everything else parks them.
        guard let view, let handPoseManager, let gameStateManager,
              gameStateManager.state == .cooking
                || gameStateManager.state == .waitingToServe else {
            abandonAllDrags()
            abandonPlateCarry()
            hideAllCursors()
            resetHoverDetector.reset()
            updateTrashProgress(0)
            return
        }

        let isCooking = gameStateManager.state == .cooking

        let viewSize = view.bounds.size
        let hands = handPoseManager.hands
        retireVanishedHands(stillLive: Set(hands.map(\.id)), now: now)

        var frameHands: [FrameHand] = []

        for hand in hands {
            let cursor = convertPoint(fromView: handPoseManager.cursor(for: hand, in: viewSize))
            let state: HandState = hand.isClosedFist ? .fist : hand.isOpenHand ? .open : .unknown
            var tracker = trackers[hand.id] ?? HandTracker()
            tracker.lastSeen = now

            var handPoints = handPoseManager.jointPoints(for: hand, in: viewSize)
                .map(convertPoint(fromView:))
            handPoints.append(cursor)

            frameHands.append(FrameHand(cursor: cursor,
                                        isOpen: state == .open,
                                        isHolding: tracker.held != nil))

            updateCursorNode(for: hand.id, at: cursor, isFist: state == .fist)

            guard isCooking else {
                carryPlate(
                    handID: hand.id,
                    cursor: cursor,
                    handPoints: handPoints,
                    state: state,
                    now: now,
                    delta: delta,
                    gameStateManager: gameStateManager
                )
                tracker.previousState = state
                trackers[hand.id] = tracker
                continue
            }

            // Grab when the hand closes into a fist (from any prior state).
            if state == .fist, tracker.previousState != .fist, tracker.held == nil {
                if let grabbed = grabCandidate(touchedBy: handPoints) {
                    grabbed.heldBy = hand.id
                    grabbed.zPosition = 100
                    grabbed.removeAllActions()
                    grabbed.setScale(1)
                    tracker.held = grabbed
                }
            }

            // Carry: follow the hand whatever the pose reads as this frame.
            // Gating this on `.fist` meant a single misread frame froze the
            // bubble in mid-air — a visible stutter even when the release
            // below rides that frame out.
            //
            // Eased rather than assigned, so the bubble glides between the
            // tracker's 30Hz updates instead of stepping to each one.
            if let held = tracker.held {
                // Kept on screen, and kept off the reset button: carrying an
                // ingredient over the control the player is about to need
                // hides it, and used to delete the ingredient outright.
                let target = Self.pushedOut(
                    Self.clamped(cursor, radius: held.radius, in: size),
                    awayFrom: resetNode.position,
                    keepOut: resetRadius + held.radius
                )
                held.position = held.position.vc_eased(
                    toward: target,
                    by: Self.easing(base: dragSmoothing, delta: delta)
                )

                if held.position.vc_distance(to: plateHome) <= plateRadius + held.radius * 0.5 {
                    commitToPlate(held, gameStateManager: gameStateManager)
                    tracker.held = nil
                    tracker.openSince = nil
                }
            }

            // Release only once the hand has *stayed* open. Every frame reads
            // as either fist or open with nothing in between, so acting on the
            // first open frame drops ingredients the player never let go of.
            if let held = tracker.held {
                if state == .open {
                    let openedAt = tracker.openSince ?? now
                    tracker.openSince = openedAt

                    if now - openedAt >= releaseDelay {
                        releaseOntoTable(held)
                        tracker.held = nil
                        tracker.openSince = nil
                    }
                } else {
                    tracker.openSince = nil
                }
            }

            tracker.previousState = state
            trackers[hand.id] = tracker
        }

        if isCooking {
            detectTrashHover(frameHands, gameStateManager: gameStateManager, now: now)
        } else {
            resetHoverDetector.reset()
            updateTrashProgress(0)
        }
    }

    // MARK: - Carrying the plate to the bell

    /// Grab the finished plate and walk it over to the bell.
    ///
    /// This replaced a swipe. A swipe asked the player to flick at empty air
    /// in the right direction; carrying asks them to pick the plate up and
    /// take it somewhere, which is both the same motion they already use for
    /// ingredients and an obvious reading of what serving a dish means.
    func carryPlate(
        handID: Int,
        cursor: CGPoint,
        handPoints: [CGPoint],
        state: HandState,
        now: TimeInterval,
        delta: TimeInterval,
        gameStateManager: GameStateManager
    ) {
        guard let plateNode else { return }

        // Pick it up: a fist closing anywhere on the plate takes it.
        if state == .fist, plateHeldBy == nil,
           handPoints.contains(where: {
               $0.vc_distance(to: plateNode.position) <= plateRadius + grabSlack
           }) {
            plateHeldBy = handID
            plateOpenSince = nil
            plateNode.removeAllActions()
        }

        guard plateHeldBy == handID else { return }

        // Carried with the same easing an ingredient gets, so both feel like
        // the same object in the hand — and kept below the HUD, since the
        // score and hearts cards are opaque and would swallow it whole.
        let target = Self.clampedBelowHUD(
            cursor,
            radius: plateRadius,
            in: size,
            hudHeight: hudExclusion
        )
        plateNode.position = plateNode.position.vc_eased(
            toward: target,
            by: Self.easing(base: dragSmoothing, delta: delta)
        )

        // Reaching the bell *is* serving — there is nothing else to do there,
        // so it fires on arrival rather than asking for a second gesture.
        if let bell = bellNode,
           plateNode.position.vc_distance(to: bell.position)
            <= plateRadius + bell.size.width / 2 {
            lastServeDirection = gameStateManager.bellSide
            plateHeldBy = nil
            plateOpenSince = nil
            gameStateManager.serveDish()
            return
        }

        // Let go short of the bell and the plate settles back home, ready to
        // be picked up again. Same debounce as an ingredient, so one misread
        // frame doesn't drop it halfway.
        if state == .open {
            let openedAt = plateOpenSince ?? now
            plateOpenSince = openedAt

            if now - openedAt >= releaseDelay {
                releasePlateHome()
            }
        } else {
            plateOpenSince = nil
        }
    }

    /// Lets go of the plate and floats it back to the table, ready to be
    /// picked up again.
    func releasePlateHome() {
        plateHeldBy = nil
        plateOpenSince = nil

        guard let plateNode else { return }
        plateNode.removeAllActions()

        let home = SKAction.move(to: plateHome, duration: 0.3)
        home.timingMode = .easeOut
        plateNode.run(home)
    }

    /// Puts the plate down where it belongs — the game left the serve phase
    /// while somebody was still holding it.
    func abandonPlateCarry() {
        guard plateHeldBy != nil else { return }
        plateHeldBy = nil
        plateOpenSince = nil
        plateNode?.position = plateHome
    }

    // MARK: - Trash hover

    /// An open, empty hand held over the trash bin for two seconds dumps
    /// whatever is on the plate.
    ///
    /// Deliberately a dwell on a fixed target rather than a pose: it needs only
    /// one hand, and holding still over the bin is not something the player
    /// does by accident while ferrying ingredients into the bowl.
    func detectTrashHover(_ hands: [FrameHand], gameStateManager: GameStateManager, now: TimeInterval) {
        let reach = resetRadius + grabSlack

        // Open *and* empty: on the frame a hand opens to drop a bubble it is
        // still recorded as holding, so this keeps the release itself from
        // counting as the opening frame of a dwell.
        let isHovering = hands.contains {
            $0.isOpen && !$0.isHolding
                && $0.cursor.vc_distance(to: resetNode.position) <= reach
        }

        let fired = resetHoverDetector.update(isHovering: isHovering, now: now)
        updateTrashProgress(resetHoverDetector.progress)
        if fired { gameStateManager.discardPlate() }
    }

    /// Draws the dwell as an arc closing around the bin. Without it the
    /// two-second wait is invisible and reads as the gesture not working.
    func updateTrashProgress(_ progress: CGFloat) {
        guard progress > 0 else {
            resetProgressNode?.removeFromParent()
            resetProgressNode = nil
            return
        }

        let ring: SKShapeNode
        if let existing = resetProgressNode {
            ring = existing
        } else {
            ring = SKShapeNode()
            ring.strokeColor = .white
            ring.lineWidth = 5
            ring.lineCap = .round
            ring.fillColor = .clear
            ring.zPosition = 2
            resetNode.addChild(ring)
            resetProgressNode = ring
        }

        // Sweeps clockwise from 12 o'clock, the way a countdown reads.
        let path = CGMutablePath()
        path.addArc(
            center: .zero,
            radius: resetRadius + 8,
            startAngle: .pi / 2,
            endAngle: .pi / 2 - .pi * 2 * progress,
            clockwise: true
        )
        ring.path = path
    }

    // MARK: - Grab candidate

    /// Finds the nearest ingredient bubble that any joint of the
    /// hand is touching. Ignores things already on the plate or
    /// held by the other hand.
    func grabCandidate(touchedBy handPoints: [CGPoint]) -> IngredientNode? {
        guard !handPoints.isEmpty else { return nil }

        var best: (node: IngredientNode, distance: CGFloat)?
        for node in tableIngredients()
        where !node.isOnPlate && node.heldBy == nil {
            let reach = node.radius + grabSlack
            guard let nearest = handPoints.map({ $0.vc_distance(to: node.position) }).min(),
                  nearest <= reach else { continue }
            if best == nil || nearest < best!.distance {
                best = (node, nearest)
            }
        }
        return best?.node
    }

    // MARK: - Play area

    /// Pins a point far enough inside the scene that a bubble of `radius`
    /// stays fully on screen.
    ///
    /// The cursor itself is deliberately *not* clamped — a hand reaching past
    /// the edge of the camera's view maps to a point outside the scene, and
    /// that is honest about where the hand is. It's the ingredient that must
    /// not follow it out, because once a bubble leaves the frame there is no
    /// way to reach it again.
    ///
    /// `max` on the upper bound because a scene narrower than two radii would
    /// otherwise build a reversed range, which traps at runtime.
    /// Largest frame gap that still eases normally. Past this the scene has
    /// stalled, and closing a huge fraction of the gap in one go would snap a
    /// carried bubble across the screen.
    static let maxEasingDelta: TimeInterval = 0.1

    /// Turns a per-60Hz-frame easing fraction into one for a frame that
    /// actually lasted `delta`.
    ///
    /// `base` is how much of the remaining gap to close in one frame at 60Hz.
    /// An iPad Pro draws at 120, where frames are half as long — closing the
    /// same fraction each time would make a dragged bubble twice as twitchy on
    /// the very device this is tuned on.
    static func easing(base: CGFloat, delta: TimeInterval) -> CGFloat {
        guard base > 0 else { return 0 }
        guard base < 1 else { return 1 }

        // No previous frame to measure against — take the base as given.
        guard delta > 0 else { return base }

        let elapsed = min(delta, maxEasingDelta)
        return CGFloat(1 - pow(1 - Double(base), elapsed * 60))
    }

    /// Nudges a point out to the edge of a circular no-go zone, if it is
    /// inside one.
    ///
    /// Applied after the screen clamp, so in the corner where the reset button
    /// sits the on-screen rule wins — a bubble pinned just inside the zone is
    /// a smaller problem than one shoved off the board.
    static func pushedOut(
        _ point: CGPoint,
        awayFrom centre: CGPoint,
        keepOut: CGFloat
    ) -> CGPoint {
        guard keepOut > 0 else { return point }

        let offset = CGPoint(x: point.x - centre.x, y: point.y - centre.y)
        let distance = hypot(offset.x, offset.y)
        guard distance < keepOut else { return point }

        // Dead centre leaves no direction to push along; up is as good as any.
        guard distance > 0 else { return CGPoint(x: centre.x, y: centre.y + keepOut) }

        let scale = keepOut / distance
        return CGPoint(x: centre.x + offset.x * scale, y: centre.y + offset.y * scale)
    }

    /// Clamps into the play area: on screen, and below the HUD.
    ///
    /// The score, recipe and hearts cards are drawn by SwiftUI *over* the
    /// scene and are not transparent, so anything the player still has to see
    /// or reach has to stay out from under them.
    static func clampedBelowHUD(
        _ point: CGPoint,
        radius: CGFloat,
        in size: CGSize,
        hudHeight: CGFloat
    ) -> CGPoint {
        let onScreen = clamped(point, radius: radius, in: size)
        let ceiling = max(radius, size.height - hudHeight - radius)

        return CGPoint(x: onScreen.x, y: min(onScreen.y, ceiling))
    }

    static func clamped(_ point: CGPoint, radius: CGFloat, in size: CGSize) -> CGPoint {
        CGPoint(
            x: point.x.vc_clamped(to: radius...max(radius, size.width - radius)),
            y: point.y.vc_clamped(to: radius...max(radius, size.height - radius))
        )
    }

    // MARK: - Cursors

    /// Shows a green (fist) or red (open) circle at the hand position.
    func updateCursorNode(for id: Int, at position: CGPoint, isFist: Bool) {
        let node: SKShapeNode
        if let existing = cursorNodes[id] {
            node = existing
        } else {
            node = SKShapeNode(circleOfRadius: 22)
            node.strokeColor = .white
            node.lineWidth = 3
            node.zPosition = 1000
            addChild(node)
            cursorNodes[id] = node
        }
        node.isHidden = false
        node.position = position
        node.fillColor = isFist
            ? SKColor.systemGreen.withAlphaComponent(0.75)
            : SKColor.systemRed.withAlphaComponent(0.65)
    }

    func hideAllCursors() {
        cursorNodes.values.forEach { $0.isHidden = true }
    }

    // MARK: - Hand lifecycle

    /// Drops whatever a vanished hand was holding so it isn't stuck
    /// in mid-air forever. Hands holding an item get a 0.35s grace
    /// period so brief tracking dropouts don't release mid-drag.
    func retireVanishedHands(stillLive: Set<Int>, now: TimeInterval) {
        for (id, tracker) in trackers where !stillLive.contains(id) {
            if tracker.held != nil, now - tracker.lastSeen <= heldHandGrace {
                cursorNodes[id]?.isHidden = true
                continue
            }
            if let held = tracker.held { releaseOntoTable(held) }

            // The plate needs the same treatment ingredients already got.
            // Without this it stays owned by a hand that no longer exists:
            // `carryPlate` only moves it for the owning id, and picking it up
            // requires no owner at all, so nothing on screen can touch it
            // again. Reaching for the HUD at the top of the screen pushes the
            // hand out of the camera's view, which is exactly how players hit
            // this.
            if plateHeldBy == id { releasePlateHome() }

            trackers[id] = nil
            cursorNodes[id]?.removeFromParent()
            cursorNodes[id] = nil
        }
    }

    /// Drops everything held without committing — used when the game
    /// leaves `.cooking` mid-drag.
    func abandonAllDrags() {
        for (id, tracker) in trackers {
            if let held = tracker.held {
                held.heldBy = nil
                held.zPosition = 2
            }
            trackers[id] = HandTracker()
        }
    }
}
