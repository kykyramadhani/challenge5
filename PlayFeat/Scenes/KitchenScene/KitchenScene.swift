//
//  KitchenScene.swift
//  PlayFeat
//
//  The transparent SpriteKit layer every kitchen role plays on. It draws the
//  purple glow on each hand and whatever a hand carries, and runs the hand
//  mechanics the roles share: pinch to pick up, carry, open the fingers to
//  let go — GameScene's slack, smoothing, release delay and tracking grace —
//  plus feeding hands to motion recognizers while a zoomed-in panel is open.
//
//  A role subclasses it and says only what is different: what a hand can pick
//  up, where it can be let go, and which gesture a panel listens for. Progress
//  only ever comes from hands actually seen — a hand coasting through a
//  tracking gap is drawn but never acted on.
//

import SpriteKit

class KitchenScene: SKScene {
    weak var handInput: (any HandInputSource)?
    weak var audio: (any SoundPlaying)?

    /// One hand this frame. View space for hit-testing against the layout,
    /// scene space (y up) for drawing and the recognizers.
    struct Hand {
        let id: Int
        let viewPoint: CGPoint
        let scenePoint: CGPoint
        let reach: [CGPoint]
        let isPinching: Bool
        let side: HandSide?
        /// Coasting through a tracking gap — drawn, never acted on.
        let isPredicted: Bool
        let confidence: CGFloat
    }

    /// Something a hand is carrying.
    private struct Grip {
        let item: CarriedItem
        let node: SKNode
        /// Where it was picked up, so a refused drop can float back there.
        let origin: CGPoint
        var position: CGPoint
        var openSince: TimeInterval?
        var lastSeen: TimeInterval
    }

    // Hand mechanics, the values GameScene uses.
    private let grabSlack: CGFloat = 30
    private let dragSmoothing: CGFloat = 0.5
    private let releaseDelay: TimeInterval = 0.18
    private let heldHandGrace: TimeInterval = 0.35

    private var grips: [Int: Grip] = [:]
    private var wasPinching: [Int: Bool] = [:]
    private var glows: [Int: HandGlowNode] = [:]
    private var lastUpdateTime: TimeInterval = 0

    /// One motion recognizer per hand while a panel is open.
    private var motions: [Int: MotionRecognizer] = [:]
    private var lastPoints: [Int: CGPoint] = [:]

    #if DEBUG
    private(set) var diagnostics: TrackingDiagnosticsNode?
    #endif

    #if targetEnvironment(simulator)
    /// The simulator has no camera: a finger stands in for a hand.
    private var touchHands: [ObjectIdentifier: (id: Int, point: CGPoint)] = [:]
    private var nextTouchID = 10_000
    #endif

    private let layoutType: any KitchenLayout.Type

    var shortEdge: CGFloat { min(size.width, size.height) }

    /// The role's layout: hand sizes, the carried bubble and the work area.
    var layout: any KitchenLayout { layoutType.init(size: size) }

    init(size: CGSize, layout: any KitchenLayout.Type) {
        layoutType = layout
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("Kitchen scenes are built in code, never from an .sks file")
    }

    // MARK: - What a role fills in

    /// Runs one frame of the role's play with this frame's hands.
    func play(_ hands: [Hand], now: TimeInterval, delta: TimeInterval) {}

    /// Everything a hand could pick up right now, with where it sits.
    func carryTargets() -> [(item: CarriedItem, rect: CGRect)] { [] }

    /// Every place an item can be let go over, with its area.
    func dropTargets() -> [(zone: DropZone, rect: CGRect)] { [] }

    /// A pinch started on something that is pressed rather than carried
    /// (Front House's dispenser). Returns whether it took the pinch.
    func press(by hand: Hand) -> Bool { false }

    /// Where `item`, let go over `zone`, flies to.
    func dropPoint(for item: CarriedItem, at zone: DropZone) -> CGPoint { .zero }

    func accepts(_ item: CarriedItem, at zone: DropZone) -> Bool { false }

    func drop(_ item: CarriedItem, at zone: DropZone) {}

    /// A hand picked `item` up, or it went back where it came from.
    func didPickUp(_ item: CarriedItem) {}
    func didPutBack(_ item: CarriedItem) {}

    /// Whether a simulator finger counts as a pinching hand right now.
    var touchIsPinching: Bool { true }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        lastUpdateTime = currentTime

        let hands = currentHands()
        drawGlows(for: hands)
        #if DEBUG
        showDiagnostics(for: hands)
        #endif
        play(hands, now: currentTime, delta: delta)
    }

    private func currentHands() -> [Hand] {
        var hands: [Hand] = []
        if let handInput, let view {
            let viewSize = view.bounds.size
            hands = handInput.hands.map { hand in
                let cursor = handInput.cursor(for: hand, in: viewSize)
                return Hand(id: hand.id, viewPoint: cursor, scenePoint: convertPoint(fromView: cursor),
                            reach: handInput.jointPoints(for: hand, in: viewSize) + [cursor],
                            isPinching: hand.isClosedFist, side: hand.side,
                            isPredicted: hand.isPredicted, confidence: hand.trackingConfidence)
            }
        }
        #if targetEnvironment(simulator)
        // Touches have no anatomy: the screen half a finger is on stands in
        // for which hand it is.
        hands += touchHands.values.map {
            Hand(id: $0.id, viewPoint: $0.point, scenePoint: convertPoint(fromView: $0.point),
                 reach: [$0.point], isPinching: touchIsPinching,
                 side: $0.point.x < size.width / 2 ? .left : .right, isPredicted: false, confidence: 1)
        }
        #endif
        return hands
    }

    // MARK: - Hand glow

    private func drawGlows(for hands: [Hand]) {
        let live = Set(hands.map(\.id))
        for (id, glow) in glows where !live.contains(id) {
            glow.fadeOutAndRemove()
            glows[id] = nil
        }
        for hand in hands {
            let glow = glows[hand.id] ?? makeGlow(for: hand.id)
            glow.setVisible(true)
            glow.position = hand.scenePoint
            glow.setGrabbing(hand.isPinching)
            // Fades through a tracking gap instead of blinking out.
            glow.alpha = max(0.35, hand.confidence)
        }
    }

    private func makeGlow(for id: Int) -> HandGlowNode {
        // Sized as GameScene sizes its glow, so the hands look the same in both.
        let radius = (shortEdge * 0.17).clamped(to: 68 * layout.scale...100 * layout.scale)
        let glow = HandGlowNode(radius: radius,
                                openColor: HandGlowNode.kitchenOpenColor,
                                grabColor: HandGlowNode.kitchenGrabColor)
        glow.zPosition = GameScene.glowZ
        addChild(glow)
        glow.attachTrail(to: self)
        glows[id] = glow
        return glow
    }

    #if DEBUG
    /// The `-debugTracking` overlay: each hand's side, seen/predicted state
    /// and confidence.
    private func showDiagnostics(for hands: [Hand]) {
        guard DebugLaunch.showsTrackingDiagnostics else { return }
        let overlay = diagnostics ?? {
            let node = TrackingDiagnosticsNode(topLeft: CGPoint(x: 20, y: size.height - 20))
            addChild(node)
            diagnostics = node
            return node
        }()
        overlay.show(hands.map { hand in
            let side = hand.side.map { $0 == .left ? "L" : "R" } ?? "?"
            let state = hand.isPredicted ? "predicted" : "seen"
            return .init(id: hand.id, position: hand.scenePoint,
                         text: String(format: "%@ %@ %.2f", side, state, hand.confidence))
        })
    }
    #endif

    // MARK: - Carrying

    /// Everything hands are carrying right now.
    var heldItems: [CarriedItem] { grips.values.map(\.item) }

    func carry(_ hands: [Hand], now: TimeInterval, delta: TimeInterval) {
        for hand in hands {
            // A coasting hand holds on to what it carries, but can't move it,
            // drop it, or grab anything until it is really seen again.
            guard !hand.isPredicted else {
                grips[hand.id]?.lastSeen = now
                continue
            }
            let pinchStarted = hand.isPinching && wasPinching[hand.id] != true
            wasPinching[hand.id] = hand.isPinching

            guard var grip = grips[hand.id] else {
                if pinchStarted, !press(by: hand), let target = grabbable(by: hand) {
                    grab(target.item, from: target.rect.center, by: hand, now: now)
                }
                continue
            }
            grip.lastSeen = now
            grip.position = carried(grip.position, toward: hand.viewPoint, delta: delta)
            grip.node.position = convertPoint(fromView: grip.position)

            if hand.isPinching {
                grip.openSince = nil
            } else {
                let openedAt = grip.openSince ?? now
                grip.openSince = openedAt
                if now - openedAt >= releaseDelay {
                    grips[hand.id] = nil
                    release(grip)
                    continue
                }
            }
            grips[hand.id] = grip
        }
        letGoOfLostHands(present: Set(hands.map(\.id)), now: now)
    }

    /// What a pinch starting here picks up: the nearest thing any joint of
    /// the hand is within reach of, as GameScene does it. Something already
    /// in another hand can't be taken again.
    private func grabbable(by hand: Hand) -> (item: CarriedItem, rect: CGRect)? {
        var held = heldItems
        let free = carryTargets().filter { target in
            guard let index = held.firstIndex(of: target.item) else { return true }
            held.remove(at: index)
            return false
        }
        let reachable = free.filter { target in
            let zone = target.rect.insetBy(dx: -grabSlack, dy: -grabSlack)
            return hand.reach.contains(where: zone.contains)
        }
        return reachable.min {
            hand.viewPoint.distance(to: $0.rect.center) < hand.viewPoint.distance(to: $1.rect.center)
        }
    }

    private func grab(_ item: CarriedItem, from origin: CGPoint, by hand: Hand, now: TimeInterval) {
        let node = CarriedItemNode(item: item, diameter: layout.heldBubbleDiameter)
        node.position = convertPoint(fromView: origin)
        node.zPosition = GameScene.heldZ
        addChild(node)
        grips[hand.id] = Grip(item: item, node: node, origin: origin, position: origin, lastSeen: now)
        didPickUp(item)
        audio?.play(.bubbleGrab)
    }

    /// Lets go: the nearest place that takes the item, within reach, gets
    /// it; anywhere else it floats back where it came from and nothing
    /// changes.
    private func release(_ grip: Grip) {
        let targets = dropTargets()
        let taking = targets.filter { accepts(grip.item, at: $0.zone) }
        guard let zone = type(of: layout).nearestTarget(to: grip.position, among: taking, reach: layout.dropReach)
        else {
            if targets.contains(where: { $0.rect.contains(grip.position) }) { audio?.play(.wrongIngredient) }
            floatBack(grip)
            return
        }
        drop(grip.item, at: zone)
        audio?.play(.bubblePut)
        let target = convertPoint(fromView: dropPoint(for: grip.item, at: zone))
        let away = SKAction.group([
            .move(to: target, duration: 0.3),
            .scale(to: 0.1, duration: 0.3),
            .rotate(byAngle: zone.isPortal ? .pi * 2 : 0, duration: 0.3),
        ])
        grip.node.run(.sequence([away, .removeFromParent()]))
    }

    private func floatBack(_ grip: Grip) {
        let home = SKAction.move(to: convertPoint(fromView: grip.origin), duration: 0.3)
        home.timingMode = .easeOut
        let item = grip.item
        grip.node.run(.sequence([home, .fadeOut(withDuration: 0.15), .removeFromParent()])) { [weak self] in
            self?.didPutBack(item)
        }
    }

    /// A hand Vision lost while carrying keeps its item for `heldHandGrace`,
    /// then the item goes back where it came from.
    private func letGoOfLostHands(present: Set<Int>, now: TimeInterval) {
        for (id, grip) in grips where !present.contains(id) && now - grip.lastSeen > heldHandGrace {
            grips[id] = nil
            floatBack(grip)
        }
        wasPinching = wasPinching.filter { present.contains($0.key) }
    }

    func putEverythingBack() {
        grips.values.forEach(floatBack)
        grips = [:]
    }

    /// Eased toward the hand, kept fully on screen — GameScene's carry.
    private func carried(_ point: CGPoint, toward cursor: CGPoint, delta: TimeInterval) -> CGPoint {
        let radius = layout.heldBubbleDiameter / 2
        let target = GameScene.clamped(cursor, radius: radius, in: size)
        return point.eased(toward: target, by: GameScene.easing(base: dragSmoothing, delta: delta))
    }

    // MARK: - Motions in a zoomed-in panel

    /// Drops any half-done motion and anything carried — a panel opened or
    /// closed.
    func resetMotions() {
        putEverythingBack()
        motions = [:]
        lastPoints = [:]
    }

    /// Hands inside the open panel. One that left it, or was lost for good,
    /// starts its motion over when it comes back.
    func handsInWorkArea(_ hands: [Hand]) -> [Hand] {
        let working = hands.filter { layout.workArea.contains($0.viewPoint) }
        let present = Set(working.map(\.id))
        motions = motions.filter { present.contains($0.key) }
        lastPoints = lastPoints.filter { present.contains($0.key) }
        return working
    }

    /// Progress units (circles, strokes) this hand's newest point completes.
    func feed(_ hand: Hand, motion: ProcessMotion, delta: TimeInterval) -> Double {
        var recognizer = motions[hand.id] ?? MotionRecognizer(
            motion: motion,
            minStep: shortEdge * 0.008,
            strokeLength: shortEdge * 0.06
        )
        // Tracking that comes back somewhere else is a jump, not a stroke.
        if let last = lastPoints[hand.id], last.distance(to: hand.scenePoint) > shortEdge * 0.2 {
            recognizer.reset()
        }
        let units = recognizer.feed(hand.scenePoint, dt: delta)
        motions[hand.id] = recognizer
        lastPoints[hand.id] = hand.scenePoint
        return units
    }

    /// Forgets one hand's half-done motion.
    func resetMotion(of hand: Hand) {
        motions[hand.id] = nil
        lastPoints[hand.id] = nil
    }

    // MARK: - Touch stand-in (simulator only)

    #if targetEnvironment(simulator)
    /// Two fingers stand in for two hands, which chopping needs.
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        view.isMultipleTouchEnabled = true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        for touch in touches {
            touchHands[ObjectIdentifier(touch)] = (nextTouchID, touch.location(in: view))
            nextTouchID += 1
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        for touch in touches {
            touchHands[ObjectIdentifier(touch)]?.point = touch.location(in: view)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { endTouches(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { endTouches(touches) }

    /// A lifted finger is an opened hand: what it carried is let go at once.
    private func endTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            guard let hand = touchHands.removeValue(forKey: ObjectIdentifier(touch)) else { continue }
            wasPinching[hand.id] = nil
            if let grip = grips.removeValue(forKey: hand.id) {
                release(grip)
            }
        }
    }
    #endif
}
