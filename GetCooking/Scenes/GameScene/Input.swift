//
//  GameScene+HandInput.swift
//  GetCooking
//
//  Reads hand-pose data every frame and turns it into grab, drag,
//  release, and clap interactions.
//

import SpriteKit

extension GameScene {

    /// A snapshot of one hand this frame, in scene coordinates.
    struct FrameHand {
        let cursor: CGPoint
        let span: CGFloat
        let isHolding: Bool
    }

    // MARK: - Per-frame hand processing

    /// Reads every tracked hand, converts its joints from view space
    /// (top-left origin, y-down) to scene space (bottom-left, y-up),
    /// and runs the grab / drag / release / clap logic.
    func updateHandInput(now: TimeInterval) {
        guard let view, let handPoseManager, let gameStateManager,
              gameStateManager.state == .cooking else {
            abandonAllDrags()
            hideAllCursors()
            clapDetector.disarm()
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

            let span = handPoints.map { $0.vc_distance(to: cursor) }.max() ?? 0
            frameHands.append(FrameHand(cursor: cursor, span: span, isHolding: tracker.held != nil))

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

        detectClap(frameHands, gameStateManager: gameStateManager, now: now)
    }

    // MARK: - Clap detection

    /// Two empty hands brought together over the plate dumps
    /// whatever is on it.
    func detectClap(_ hands: [FrameHand], gameStateManager: GameStateManager, now: TimeInterval) {
        guard hands.count == 2 else {
            clapDetector.disarm()
            return
        }
        let (left, right) = (hands[0], hands[1])

        let clapped = clapDetector.update(
            left: left.cursor,
            right: right.cursor,
            span: max((left.span + right.span) / 2, 1),
            bothHandsEmpty: !left.isHolding && !right.isHolding,
            target: plateHome,
            targetRadius: plateRadius + grabSlack,
            now: now
        )
        if clapped { gameStateManager.discardPlate() }
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
