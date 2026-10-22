//
//  FrontHouseGame.swift
//  PlayFeat
//
//  Runs a Front House shift on top of the shared `KitchenShift` (orders,
//  clock, lives, score): the five floating dishes from the Chef, the clean
//  trays from Procurement, assembling the active order's tray, the drink
//  dispenser, serving, the customer eating and the dirty tray going back.
//  The single source of truth the SwiftUI counter and FrontHouseScene read.
//
//  An order's lifecycle here: set a clean tray down → fill its compartments
//  → carry it to that order's ticket; any waiting order can be picked. A
//  drink, if asked for, is carried to the ticket on its own, before or after
//  the tray; the order is only served once both are there, and stays on the
//  clock until then. Served, it keeps its place on the rail with its tray on
//  the table. The customer eats for `eatTime`, a
//  dirty tray appears, and only once that goes through the Procurement
//  portal is the order complete: the rail slides left and a new order is
//  dealt at the end.
//
//  In the playtest the player is the only Front House and nobody plays the
//  other roles: dishes arrive as soon as an order wants them, and dirty
//  trays come back washed after `washTime`.
//

import Foundation
import QuartzCore

@Observable
final class FrontHouseGame {

    /// Where the player is working: the counter, or the dispenser zoomed in.
    enum Station: Equatable {
        case counter
        case pouring
    }

    static let eatTime: TimeInterval = 3
    /// How long the stand-in Procurement takes to wash a returned tray.
    static let washTime: TimeInterval = 8
    /// How long the tap has to run to fill a glass.
    static let pourTime: TimeInterval = 2
    static let startingCleanTrays = 3
    /// How long a filled glass stays on screen before the dispenser closes.
    static let finishedBeat: TimeInterval = 0.9

    // MARK: - State

    let shift: KitchenShift
    private(set) var station: Station = .counter
    private(set) var rack = BubbleRack()
    /// The shared tray inventory: `cleanTrays` are Front House's,
    /// `dirtyTrays` are back at Procurement.
    private(set) var crew: KitchenCrew
    /// The tray on the counter, nil until a clean one is set down.
    private(set) var tray: ServingTray?
    /// A filled glass waits by the dispenser.
    private(set) var isDrinkReady = false
    /// 0...1 up the glass while pouring.
    private(set) var fill = 0.0
    private(set) var isTapOpen = false
    /// Bubbles the player let go of away from any target, where they were
    /// left (fractions of the screen). The rest float in their own slot.
    private(set) var bubbleSpots: [CarriedItem: CGPoint] = [:]
    /// What hands are carrying, so the counter doesn't also draw it in place.
    private(set) var itemsInHand: [CarriedItem] = []

    /// When each served order's customer started eating, by order id.
    @ObservationIgnored private var eatingSince: [KitchenOrder.ID: TimeInterval] = [:]
    @ObservationIgnored private var washedAt: [TimeInterval] = []
    @ObservationIgnored private var stationFinishedAt: TimeInterval?
    @ObservationIgnored private var lastTick: TimeInterval = 0
    /// The rail as last seen, to notice orders arriving and leaving.
    @ObservationIgnored private var knownRail: [KitchenOrder.ID] = []

    init(mode: KitchenMode,
         wallTime: TimeInterval = CACurrentMediaTime(),
         crew: KitchenCrew = KitchenCrew(cleanTrays: startingCleanTrays, dirtyTrays: 0),
         makeOrder: @escaping (Int) -> KitchenOrder = KitchenOrder.random) {
        shift = KitchenShift(mode: mode, wallTime: wallTime, makeOrder: makeOrder)
        self.crew = crew
        shift.onTick = { [weak self] in self?.tick(wallTime: $0) }
        catchUpWithRail()
    }

    var queue: OrderQueue { shift.queue }
    var isOver: Bool { shift.isOver }
    var now: TimeInterval { shift.now }
    var bubbles: [FloatingBubble?] { rack.slots }

    /// One step of the shift. Internal so tests can drive the clock.
    func tick(wallTime: TimeInterval) {
        guard !isOver else { return }
        shift.advanceClock(to: wallTime)
        pour(for: now - lastTick)
        lastTick = now
        finishEating()
        returnWashedTrays()
        closeFinishedStation()
        failExpiredOrders()
        catchUpWithRail()
    }

    // MARK: - Dropping things

    /// Whether letting go of `item` over `zone` does something. Anything it
    /// doesn't accept floats back where it came from.
    func accepts(_ item: CarriedItem, at zone: DropZone) -> Bool {
        guard station == .counter, !isOver else { return false }
        switch (item, zone) {
        case (.cleanTray, .assemblyTray):
            return tray == nil && crew.cleanTrays > 0
        case let (.dish(dish, slot), .compartment(compartment)):
            guard rack.holds(dish, in: slot), let tray else { return false }
            return ordersWantingTrays.contains { tray.canPlace(dish, in: compartment, for: $0) }
        case let (.drink, .ticket(index)):
            return isDrinkReady && waitingOrder(at: index)?.isDrinkOwed == true
        case let (.servingTray(carried), .ticket(index)):
            guard carried == tray, let order = waitingOrder(at: index), !order.isTrayServed else { return false }
            return carried.isComplete(for: order)
        case (.dirtyTray, .procurementPortal):
            return queue.orders.contains { $0.stage == .finishedEating }
        default:
            return false
        }
    }

    /// Lets go of `item` over `zone`. Does nothing unless `accepts` agrees, so
    /// nothing is placed, served or returned twice.
    func drop(_ item: CarriedItem, at zone: DropZone) {
        guard accepts(item, at: zone) else { return }
        putBack(item)
        bubbleSpots[item] = nil
        switch (item, zone) {
        case (.cleanTray, _):
            crew.takeCleanTray()
            tray = ServingTray()
        case let (.dish(dish, slot), .compartment(compartment)):
            rack.empty(slot)
            tray?.place(dish, in: compartment)
        case let (.drink, .ticket(index)):
            guard let order = waitingOrder(at: index) else { return }
            isDrinkReady = false
            shift.serveDrink(of: order.id)
            serveIfReady(order.id)
        case let (.servingTray, .ticket(index)):
            guard let order = waitingOrder(at: index) else { return }
            tray = nil
            shift.serveTray(of: order.id)
            serveIfReady(order.id)
        case (.dirtyTray, _):
            returnDirtyTray()
        default:
            break
        }
        refreshBubbles()
    }

    /// A dish or the drink let go away from any target stays there.
    func place(_ item: CarriedItem, at spot: CGPoint) {
        switch item {
        case .dish, .drink: bubbleSpots[item] = spot
        default: break
        }
    }

    func pickUp(_ item: CarriedItem) {
        itemsInHand.append(item)
    }

    /// A carried item went back where it came from, or was used.
    func putBack(_ item: CarriedItem) {
        if let index = itemsInHand.firstIndex(of: item) { itemsInHand.remove(at: index) }
    }

    // MARK: - Serving and the dirty tray

    /// Orders served and still on the table, eating or finished.
    var traysOnTable: Int { queue.orders.filter { $0.stage != .waiting }.count }

    /// The waiting order whose ticket is at `index` on the rail.
    private func waitingOrder(at index: Int) -> KitchenOrder? {
        guard index < FrontHouseLayout.ticketCount, queue.orders.indices.contains(index) else { return nil }
        let order = queue.orders[index]
        return order.stage == .waiting ? order : nil
    }

    /// The waiting orders that still need their tray, most urgent first.
    private var ordersWantingTrays: [KitchenOrder] { queue.waiting.filter { !$0.isTrayServed } }

    /// With its tray and its drink both there, the customer starts eating.
    private func serveIfReady(_ orderID: KitchenOrder.ID) {
        guard queue.orders.first(where: { $0.id == orderID })?.isReadyToServe == true else { return }
        eatingSince[orderID] = now
        shift.serveOrder(orderID)
    }

    private func finishEating() {
        for (id, since) in eatingSince where now - since >= Self.eatTime {
            eatingSince[id] = nil
            shift.finishEating(orderID: id)
        }
    }

    /// An order is done once its dirty tray is back at Procurement.
    private func returnDirtyTray() {
        sendTrayToProcurement()
        shift.completeServedOrder()
    }

    private func sendTrayToProcurement() {
        crew.receiveDirtyTray()
        if shift.mode == .playtest { washedAt.append(now + Self.washTime) }
    }

    /// Playtest stand-in for the Procurement player: a returned tray comes
    /// back clean after `washTime`.
    private func returnWashedTrays() {
        let washed = washedAt.filter { $0 <= now }.count
        washedAt.removeAll { $0 <= now }
        for _ in 0..<washed {
            crew.takeDirtyTray()
            crew.receiveCleanTray()
        }
    }

    /// Only a waiting order runs out of time — one whose tray is served but
    /// whose drink isn't too. A tray already served goes back to Procurement
    /// to be washed. If what's on the counter tray no longer fits any order,
    /// it's thrown away; the empty tray stays for the next one.
    private func failExpiredOrders() {
        let expired = shift.expiredOrders
        guard !expired.isEmpty else { return }
        expired.filter(\.isTrayServed).forEach { _ in sendTrayToProcurement() }
        shift.failExpiredOrders()
        if let tray, !ordersWantingTrays.contains(where: tray.fits) { self.tray = ServingTray() }
    }

    /// Orders arrived or left: the bubbles look ahead to whatever is on the
    /// rail now.
    private func catchUpWithRail() {
        let rail = queue.orders.map(\.id)
        guard rail != knownRail else { return }
        knownRail = rail
        refreshBubbles()
    }

    // MARK: - The dispenser

    /// Pinching the dispenser zooms in on it, unless a filled glass is
    /// already waiting: one drink at a time.
    var canOpenDispenser: Bool {
        station == .counter && !isDrinkReady && !isOver
    }

    func openDispenser() {
        guard canOpenDispenser else { return }
        fill = 0
        isTapOpen = false
        station = .pouring
    }

    /// The handle was pulled left: drink runs while it stays open.
    func openTap() {
        guard station == .pouring, stationFinishedAt == nil else { return }
        isTapOpen = true
    }

    /// The handle was pushed back right. A full glass is done; one that
    /// isn't stays under the tap to be topped up.
    func closeTap() {
        guard station == .pouring, isTapOpen else { return }
        isTapOpen = false
        guard fill >= 1 else { return }
        isDrinkReady = true
        stationFinishedAt = now
    }

    private func pour(for seconds: TimeInterval) {
        guard isTapOpen, seconds > 0 else { return }
        fill = min(1, fill + seconds / Self.pourTime)
    }

    private func closeFinishedStation() {
        guard let finishedAt = stationFinishedAt, now - finishedAt >= Self.finishedBeat else { return }
        stationFinishedAt = nil
        station = .counter
    }

    // MARK: - Bubbles

    /// Every dish Front House still needs, most urgent order first, less
    /// what's already on the tray.
    var wantedDishes: [KitchenIngredient] {
        let onTray = tray.map { Array($0.dishes.values) } ?? []
        return ordersWantingTrays.flatMap(\.items).removingOneOfEach(onTray)
    }

    /// Five dish bubbles at most; the glass is extra, one at a time.
    private func refreshBubbles() {
        rack.refill(wanted: wantedDishes, limit: BubblePicker.slotCount)
    }
}
