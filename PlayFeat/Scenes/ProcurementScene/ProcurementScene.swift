//
//  ProcurementScene.swift
//  PlayFeat
//
//  Procurement's hands, on the shared KitchenScene mechanics:
//
//  - On the worktop: pick up a card, the sliced board or a tray, and let it
//    go over the board, the sink, a portal or the trash.
//  - With the cutting board zoomed in: `ChopDetector` counts one chop per
//    real swap of the two hands across the board's middle. With the sink
//    zoomed in: open hands feed the GestureLab circle recognizer.
//

import SpriteKit

final class ProcurementScene: KitchenScene {
    weak var game: ProcurementGame?

    private var chopDetector = ChopDetector(referenceY: 0, deadBand: 0)
    private var motionStation: ProcurementGame.Station = .worktop

    private var worktop: ProcurementLayout { ProcurementLayout(size: size) }

    init(size: CGSize) {
        super.init(size: size, layout: ProcurementLayout.self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("Kitchen scenes are built in code, never from an .sks file")
    }

    // MARK: - Frame

    override func play(_ hands: [Hand], now: TimeInterval, delta: TimeInterval) {
        guard let game, !game.isOver else {
            putEverythingBack()
            return
        }
        if game.station != motionStation { startMotions(for: game.station) }

        switch game.station {
        case .worktop:
            carry(hands, now: now, delta: delta)
        case .cutting:
            chop(with: hands, game: game)
        case .washing:
            scrub(with: hands, game: game, delta: delta)
        }
    }

    // MARK: - Carrying on the worktop

    override func carryTargets() -> [(item: CarriedItem, rect: CGRect)] {
        guard let game else { return [] }
        var targets: [(item: CarriedItem, rect: CGRect)] = game.cards.indices.map { slot in
            (.ingredient(game.cards[slot], cardSlot: slot), worktop.card(slot))
        }
        if let sliced = game.slicedOnBoard {
            targets.append((.sliced(sliced), worktop.cuttingBoard))
        }
        if let tray = availableTray(game: game) {
            targets.append((tray, worktop.trayBubble))
        }
        return targets
    }

    /// The tray a hand can take from the bubble: a clean one first, since
    /// that is the one Front House is waiting for.
    private func availableTray(game: ProcurementGame) -> CarriedItem? {
        let heldClean = heldItems.filter { $0 == .cleanTray }.count
        let heldDirty = heldItems.filter { $0 == .dirtyTray }.count
        if game.cleanTraysReady > heldClean { return .cleanTray }
        if game.crew.dirtyTrays > heldDirty { return .dirtyTray }
        return nil
    }

    override func dropTargets() -> [(zone: DropZone, rect: CGRect)] { worktop.dropTargets }

    override func dropPoint(for item: CarriedItem, at zone: DropZone) -> CGPoint { worktop.center(of: zone) }

    override func accepts(_ item: CarriedItem, at zone: DropZone) -> Bool {
        game?.accepts(item, at: zone) ?? false
    }

    override func drop(_ item: CarriedItem, at zone: DropZone) {
        game?.drop(item, at: zone)
    }

    override var touchIsPinching: Bool { game?.station == .worktop }

    // MARK: - Processing in a zoomed-in panel

    private func startMotions(for station: ProcurementGame.Station) {
        resetMotions()
        chopDetector = ChopDetector(referenceY: worktop.chopReferenceY, deadBand: shortEdge * 0.035)
        motionStation = station
    }

    /// Bare hands alternating across the board's middle like a handshake —
    /// see `ChopDetector`. Only hands seen this frame with a known side can
    /// count; any pose, pinching or not, since an edge-on chopping hand often
    /// reads as a pinch.
    private func chop(with hands: [Hand], game: ProcurementGame) {
        let verdict: ChopDetector.Verdict
        if HandInputModeSetting.stored().handCount == 1 {
            verdict = chopDetector.observe(hand: hands.first.map { chopSample($0, needsSide: false) })
        } else {
            let unidentified = hands.filter { $0.side == nil }
            let left = hands.first { $0.side == .left } ?? unidentified.first
            let right = hands.first { $0.side == .right } ?? unidentified.last
            verdict = chopDetector.observe(left: left.map { chopSample($0, needsSide: true) },
                                           right: right.map { chopSample($0, needsSide: true) })
        }
        if case .chop = verdict { game.registerChop() }
        #if DEBUG
        diagnostics?.record(verdict, detector: chopDetector)
        #endif
    }

    private func chopSample(_ hand: Hand, needsSide: Bool) -> ChopDetector.HandSample {
        ChopDetector.HandSample(y: hand.viewPoint.y,
                                isReliable: !hand.isPredicted && (!needsSide || hand.side != nil))
    }

    /// Open, empty hands circling over the tray. Both hands add up. A hand
    /// coasting through a gap keeps its half-done circle but adds nothing
    /// until it is seen again.
    private func scrub(with hands: [Hand], game: ProcurementGame, delta: TimeInterval) {
        let working = handsInWorkArea(hands)
        working.filter(\.isPinching).forEach(resetMotion)
        let circles = working
            .filter { !$0.isPinching && !$0.isPredicted }
            .reduce(0) { $0 + feed($1, motion: .circles, delta: delta) }
        if circles > 0 { game.addScrub(circles: circles) }
    }
}
