//
//  FrontHouseScene.swift
//  PlayFeat
//
//  Front House's hands, on the shared KitchenScene mechanics:
//
//  - At the counter: pick up a floating dish, a clean tray from the stand,
//    the filled glass, the assembled tray or the dirty tray, and let it go
//    over a compartment, the counter, the active ticket or the Procurement
//    portal. A pinch on the dispenser zooms in on it instead.
//  - With the dispenser zoomed in: `LeverGesture` — a pinched hand pulled
//    left opens the tap, pushed back right closes it.
//

import SpriteKit

final class FrontHouseScene: KitchenScene {
    weak var game: FrontHouseGame?

    private var lever = LeverGesture(travel: 0)
    private var motionStation: FrontHouseGame.Station = .counter

    private var counter: FrontHouseLayout { FrontHouseLayout(size: size) }

    init(size: CGSize) {
        super.init(size: size, layout: FrontHouseLayout.self)
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
        if game.station != motionStation {
            resetMotions()
            lever = LeverGesture(travel: shortEdge * 0.12)
            motionStation = game.station
        }
        switch game.station {
        case .counter: carry(hands, now: now, delta: delta)
        case .pouring: pull(with: hands, game: game)
        }
    }

    // MARK: - Carrying

    override func carryTargets() -> [(item: CarriedItem, rect: CGRect)] {
        guard let game else { return [] }
        var targets: [(item: CarriedItem, rect: CGRect)] = game.bubbles.indices.compactMap { slot in
            game.bubbles[slot].map { (.dish($0.ingredient, slot: slot), counter.bubble(slot)) }
        }
        if game.tray == nil, game.crew.cleanTrays > 0 {
            targets.append((.cleanTray, counter.trayStand))
        }
        if let tray = game.tray {
            targets.append((.servingTray(tray), counter.assemblyTray))
        }
        if game.isDrinkReady {
            targets.append((.drink, counter.drinkBubble))
        }
        for (index, order) in game.queue.orders.enumerated() where order.stage == .finishedEating {
            targets.append((.dirtyTray, counter.dirtyTrayBubble(index)))
        }
        return targets
    }

    override func press(by hand: Hand) -> Bool {
        guard let game, game.canOpenDispenser, hand.reach.contains(where: counter.dispenser.contains) else {
            return false
        }
        game.openDispenser()
        return true
    }

    override func dropTargets() -> [(zone: DropZone, rect: CGRect)] {
        counter.dropTargets(activeTicket: activeTicket)
    }

    /// A drink goes straight to its spot at the tray's corner, wherever on
    /// the tray it was let go.
    override func dropPoint(for item: CarriedItem, at zone: DropZone) -> CGPoint {
        item == .drink ? counter.drinkSpot.center : counter.center(of: zone, activeTicket: activeTicket)
    }

    private var activeTicket: Int { game?.queue.activeIndex ?? 0 }

    override func accepts(_ item: CarriedItem, at zone: DropZone) -> Bool {
        game?.accepts(item, at: zone) ?? false
    }

    override func drop(_ item: CarriedItem, at zone: DropZone) {
        game?.drop(item, at: zone)
    }

    override func didPickUp(_ item: CarriedItem) { game?.pickUp(item) }

    override func didPutBack(_ item: CarriedItem) { game?.putBack(item) }

    // MARK: - The dispenser's handle

    /// The hand on the handle: a pinching one seen this frame if there is
    /// one, else whichever hand is there.
    private func pull(with hands: [Hand], game: FrontHouseGame) {
        let working = handsInWorkArea(hands)
        let hand = working.first { $0.isPinching && !$0.isPredicted } ?? working.first
        let event = lever.observe(x: hand?.viewPoint.x, isPinching: hand?.isPinching ?? false,
                                  isReliable: hand.map { !$0.isPredicted } ?? true)
        switch event {
        case .opened: game.openTap()
        case .closed: game.closeTap()
        case nil: break
        }
    }
}
