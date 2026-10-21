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
//  (and a drink if asked) → carry it to the active ticket. Served, it keeps
//  its place on the rail with its tray on the table, and the next order is
//  active at once. The customer eats for `eatTime`, a dirty tray appears,
//  and only once that goes through the Procurement portal is the order
//  complete: the rail slides left and a new order is dealt at the end.
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
    /// Trays that can be on the table at once, so the active ticket is
    /// always one of the three on the rail.
    static let tableSeats = FrontHouseLayout.ticketCount - 1
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
    /// What hands are carrying, so the counter doesn't also draw it in place.
    private(set) var itemsInHand: [CarriedItem] = []

    /// When each served order's customer started eating, by order id.
    @ObservationIgnored private var eatingSince: [KitchenOrder.ID: TimeInterval] = [:]
    @ObservationIgnored private var washedAt: [TimeInterval] = []
    @ObservationIgnored private var stationFinishedAt: TimeInterval?
    @ObservationIgnored private var lastTick: TimeInterval = 0

    init(mode: KitchenMode,
         wallTime: TimeInterval = CACurrentMediaTime(),
         crew: KitchenCrew = KitchenCrew(cleanTrays: startingCleanTrays, dirtyTrays: 0),
         makeOrder: @escaping (Int) -> KitchenOrder = KitchenOrder.random) {
        shift = KitchenShift(mode: mode, wallTime: wallTime, makeOrder: makeOrder)
        self.crew = crew
        shift.onTick = { [weak self] in self?.tick(wallTime: $0) }
        refreshBubbles()
    }

    var queue: OrderQueue { shift.queue }
    var isOver: Bool { shift.isOver }
    var now: TimeInterval { shift.now }
    var bubbles: [FloatingBubble?] { rack.slots }
    private var active: KitchenOrder { queue.active }

    /// One step of the shift. Internal so tests can drive the clock.
    func tick(wallTime: TimeInterval) {
        guard !isOver else { return }
        shift.advanceClock(to: wallTime)
        pour(for: now - lastTick)
        lastTick = now
        finishEating()
        returnWashedTrays()
        closeFinishedStation()
        failExpiredOrder()
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
            guard rack.holds(dish, in: slot), active.stage == .waiting, let tray else { return false }
            return tray.canPlace(dish, in: compartment, for: active)
        case (.drink, .assemblyTray), (.drink, .compartment):
            guard isDrinkReady, active.stage == .waiting, let tray else { return false }
            return tray.canAddDrink(for: active)
        case let (.servingTray(carried), .activeOrder):
            return carried == tray && hasFreeSeat && carried.isComplete(for: active)
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
        switch (item, zone) {
        case (.cleanTray, _):
            crew.takeCleanTray()
            tray = ServingTray()
        case let (.dish(dish, slot), .compartment(compartment)):
            rack.empty(slot)
            tray?.place(dish, in: compartment)
        case (.drink, _):
            isDrinkReady = false
            tray?.addDrink()
        case (.servingTray, _):
            serveActiveOrder()
        case (.dirtyTray, _):
            returnDirtyTray()
        default:
            break
        }
        refreshBubbles()
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

    private var hasFreeSeat: Bool { traysOnTable < Self.tableSeats }

    private func serveActiveOrder() {
        tray = nil
        eatingSince[active.id] = now
        shift.serveActiveOrder()
    }

    private func finishEating() {
        for (id, since) in eatingSince where now - since >= Self.eatTime {
            eatingSince[id] = nil
            shift.finishEating(orderID: id)
        }
    }

    /// An order is done once its dirty tray is back at Procurement.
    private func returnDirtyTray() {
        crew.receiveDirtyTray()
        if shift.mode == .playtest { washedAt.append(now + Self.washTime) }
        shift.completeServedOrder()
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

    /// Only a waiting order runs out of time. Whatever was already on its
    /// tray is thrown away with it; the empty tray stays for the next order.
    private func failExpiredOrder() {
        guard shift.hasActiveOrderExpired else { return }
        if tray != nil { tray = ServingTray() }
        shift.failActiveOrder()
        refreshBubbles()
    }

    // MARK: - The dispenser

    /// Pinching the dispenser zooms in on it, unless a filled glass is
    /// already waiting.
    var canOpenDispenser: Bool { station == .counter && !isDrinkReady && !isOver }

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

    /// Every dish Front House still needs, most urgent first: what the
    /// waiting active order still lacks on its tray, then the orders behind
    /// it.
    var wantedDishes: [KitchenIngredient] {
        let onTray = tray.map { Array($0.dishes.values) } ?? []
        let current = active.stage == .waiting ? active.items.removingOneOfEach(onTray) : []
        return current + queue.upcoming.flatMap(\.items)
    }

    private func refreshBubbles() {
        rack.refill(wanted: wantedDishes)
    }
}
