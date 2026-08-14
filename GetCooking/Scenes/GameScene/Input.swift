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
    func updateHandInput(now: TimeInterval) {
        guard let view, let handPoseManager, let gameStateManager,
              gameStateManager.state == .cooking else {
            abandonAllDrags()
            hideAllCursors()
            resetHoverDetector.reset()
            updateTrashProgress(0)
            return
        }

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

            // Drag while fist is held.
            if state == .fist, let held = tracker.held {
                held.position = cursor
                if held.position.vc_distance(to: plateHome) <= plateRadius + held.radius * 0.5 {
                    
                    commitToPlate(held, gameStateManager: gameStateManager)
                    tracker.held = nil
                }
            }

            // Release when hand opens.
            if state == .open, let held = tracker.held {
                releaseOntoTable(held)
                tracker.held = nil
            }

            tracker.previousState = state
            trackers[hand.id] = tracker
        }

        detectTrashHover(frameHands, gameStateManager: gameStateManager, now: now)
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
        for node in children.compactMap({ $0 as? IngredientNode })
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
        let graceInterval: TimeInterval = 0.35
        for (id, tracker) in trackers where !stillLive.contains(id) {
            if tracker.held != nil, now - tracker.lastSeen <= graceInterval {
                cursorNodes[id]?.isHidden = true
                continue
            }
            if let held = tracker.held { releaseOntoTable(held) }
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
