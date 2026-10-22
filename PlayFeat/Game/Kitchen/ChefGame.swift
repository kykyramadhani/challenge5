//
//  ChefGame.swift
//  PlayFeat
//
//  Runs a Chef shift on top of the shared `KitchenShift` (orders, clock,
//  lives, score): the five floating raw ingredients Procurement has sent,
//  the three cooking stations, and handing cooked dishes to Front House.
//  The single source of truth the SwiftUI worktop and ChefScene read.
//
//  - Bubble tuber goes in the boiling pot and boils by itself; tentacle goes
//    in the fryer and fries by itself.
//  - Coral lettuce goes in the broth pot, which opens the zoomed-in pot: it
//    becomes soup only once it has been stirred with pinched, circling hands.
//  - A finished dish stays in its pot until a hand takes it out; carried
//    through the Front House portal it ticks its requirement off whichever
//    waiting order needs it, the most urgent first.
//
//  In the playtest the player is the only Chef and nobody plays Procurement:
//  mushrooms and star jelly, which never pass through the Chef, are ticked
//  off as delivered the moment their order becomes active.
//

import Foundation
import QuartzCore

@Observable
final class ChefGame {

    /// Where the player is working: the whole kitchen, or the broth pot
    /// zoomed in for stirring.
    enum Station: Equatable {
        case kitchen
        case stirring
    }

    static let boilTime: TimeInterval = 8
    static let fryTime: TimeInterval = 6
    static let circlesNeeded = 3.0
    /// How long finished soup stays in the zoomed-in pot before it closes.
    static let finishedBeat: TimeInterval = 0.9
    static let stations: [DropZone] = [.boilingPot, .brothPot, .fryer]

    // MARK: - State

    let shift: KitchenShift
    private(set) var station: Station = .kitchen
    private(set) var rack = BubbleRack()
    private(set) var pots: [DropZone: CookingPot] = [.boilingPot: .empty, .brothPot: .empty, .fryer: .empty]
    /// 0...1 through stirring the soup.
    private(set) var stirProgress = 0.0
    /// The player's own work this shift, for the shift report.
    private(set) var report = ShiftReport(role: .chef)
    /// Bubbles the player let go of away from any station, where they were
    /// left (fractions of the screen). The rest float in their own slot.
    private(set) var bubbleSpots: [CarriedItem: CGPoint] = [:]
    /// What hands are carrying, so the worktop doesn't also draw it in place.
    private(set) var itemsInHand: [CarriedItem] = []

    @ObservationIgnored private var stationFinishedAt: TimeInterval?
    /// The rail as last seen, to notice orders arriving and leaving.
    @ObservationIgnored private var knownRail: [KitchenOrder.ID] = []

    init(mode: KitchenMode,
         wallTime: TimeInterval = CACurrentMediaTime(),
         makeOrder: @escaping (Int) -> KitchenOrder = KitchenOrder.randomNeedingChef) {
        shift = KitchenShift(mode: mode, wallTime: wallTime, makeOrder: makeOrder)
        shift.onTick = { [weak self] in self?.tick(wallTime: $0) }
        catchUpWithRail()
    }

    var queue: OrderQueue { shift.queue }
    var isOver: Bool { shift.isOver }
    var now: TimeInterval { shift.now }

    /// One step of the shift. Internal so tests can drive the clock.
    func tick(wallTime: TimeInterval) {
        guard !isOver else { return }
        shift.advanceClock(to: wallTime)
        finishCooking()
        closeFinishedStation()
        settleOrders()
    }

    // MARK: - Dropping things

    /// Whether letting go of `item` over `zone` does something. Anything it
    /// doesn't accept floats back where it came from.
    func accepts(_ item: CarriedItem, at zone: DropZone) -> Bool {
        guard station == .kitchen, !isOver else { return false }
        switch item {
        case let .ingredient(ingredient, slot):
            guard rack.holds(ingredient, in: slot) else { return false }
            return zone == .trash || canStartCooking(ingredient, in: zone)
        case let .cooked(ingredient):
            guard isReady(ingredient) else { return false }
            return zone == .trash || (zone == .frontHousePortal && delivery(of: ingredient) != nil)
        default:
            return false
        }
    }

    /// Lets go of `item` over `zone`. Does nothing unless `accepts` agrees, so
    /// a dish can't be handed over twice.
    func drop(_ item: CarriedItem, at zone: DropZone) {
        guard accepts(item, at: zone) else { return }
        putBack(item)
        bubbleSpots[item] = nil
        switch item {
        case let .ingredient(ingredient, slot):
            rack.empty(slot)
            if zone != .trash { startCooking(ingredient, in: zone) }
        case let .cooked(ingredient):
            takeOut(ingredient)
            if zone == .frontHousePortal { deliver(ingredient) }
        default:
            break
        }
        refreshBubbles()
        settleOrders()
    }

    /// A raw or cooked bubble let go away from any station stays there.
    // ponytail: a cooked dish left outside still holds its pot until it's
    // delivered or trashed, so it can't be doubled; free the pot early if a
    // station ever bottlenecks.
    func place(_ item: CarriedItem, at spot: CGPoint) {
        switch item {
        case .ingredient, .cooked: bubbleSpots[item] = spot
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

    // MARK: - Cooking

    /// The raw ingredient's own station, and only while that station is free.
    private func canStartCooking(_ ingredient: KitchenIngredient, in zone: DropZone) -> Bool {
        ingredient.preparation.chefStation == zone && pots[zone]?.isEmpty == true
    }

    private func startCooking(_ ingredient: KitchenIngredient, in zone: DropZone) {
        if zone == .brothPot {
            pots[zone] = .stirring(ingredient)
            stirProgress = 0
            station = .stirring
        } else {
            pots[zone] = .cooking(ingredient, startedAt: now)
        }
    }

    static func cookTime(in zone: DropZone) -> TimeInterval {
        zone == .fryer ? fryTime : boilTime
    }

    /// 0...1 through boiling or frying, for the bar under the pot.
    func cookingProgress(in zone: DropZone) -> Double {
        switch pots[zone] {
        case let .cooking(_, startedAt): min(1, (now - startedAt) / Self.cookTime(in: zone))
        case .ready: 1
        default: 0
        }
    }

    private func finishCooking() {
        for zone in Self.stations {
            guard case let .cooking(ingredient, startedAt) = pots[zone],
                  now - startedAt >= Self.cookTime(in: zone) else { continue }
            pots[zone] = .ready(ingredient)
        }
    }

    /// The stirring gesture recognized this many circles with pinched hands.
    func addStir(circles: Double) {
        guard station == .stirring, stirProgress < 1, circles > 0,
              case let .stirring(ingredient) = pots[.brothPot] else { return }
        stirProgress = min(1, stirProgress + circles / Self.circlesNeeded)
        guard stirProgress >= 1 else { return }
        pots[.brothPot] = .ready(ingredient)
        stationFinishedAt = now
    }

    private func closeFinishedStation() {
        guard let finishedAt = stationFinishedAt, now - finishedAt >= Self.finishedBeat else { return }
        stationFinishedAt = nil
        station = .kitchen
    }

    private func isReady(_ ingredient: KitchenIngredient) -> Bool {
        guard let zone = ingredient.preparation.chefStation else { return false }
        return pots[zone]?.readyIngredient == ingredient
    }

    private func takeOut(_ ingredient: KitchenIngredient) {
        guard let zone = ingredient.preparation.chefStation else { return }
        pots[zone] = .empty
    }

    /// Cooked dishes waiting in their pots, for the "ding" when one is done.
    var readyDishCount: Int { pots.values.filter { $0.readyIngredient != nil }.count }

    // MARK: - Delivery

    /// The one check the Front House portal uses: which order's requirement
    /// a cooked `ingredient` fills, or nil when no waiting order still needs
    /// it.
    func delivery(of ingredient: KitchenIngredient) -> OrderQueue.Requirement? {
        guard ingredient.preparation.isChefWork else { return nil }
        return queue.nextOpenRequirement(for: ingredient)
    }

    /// Ticks the requirement off the moment the dish goes through.
    private func deliver(_ ingredient: KitchenIngredient) {
        guard let requirement = delivery(of: ingredient) else { return }
        shift.markDelivered(requirement)
        report.record(ingredient.preparation == .soup ? .soupCooked : .boiledOrFried)
    }

    // MARK: - Orders

    /// Finished orders leave the rail; every order that runs out of time
    /// costs a life.
    private func settleOrders() {
        // ponytail: nothing tells the Chef yet that Front House served an
        // order, so in multiplayer it never completes here; the sync will.
        shift.finishedOrders(isServed: { _ in false }).forEach { shift.complete($0.id) }
        shift.failExpiredOrders()
        catchUpWithRail()
    }

    /// Orders arrived or left: the bubbles follow whatever is on the rail
    /// now.
    private func catchUpWithRail() {
        let rail = queue.orders.map(\.id)
        guard rail != knownRail else { return }
        knownRail = rail
        handOffProcurementWork()
        refreshBubbles()
    }

    /// Playtest stand-in for the Procurement player: what goes from
    /// Procurement straight to Front House is already there.
    private func handOffProcurementWork() {
        guard shift.mode == .playtest else { return }
        for order in queue.waiting {
            for index in order.items.indices where !order.items[index].preparation.isChefWork {
                shift.markDelivered(OrderQueue.Requirement(orderID: order.id, index: index))
            }
        }
    }

    // MARK: - Bubbles

    /// Every raw ingredient the Chef still needs, most urgent order first —
    /// less what is already in a pot.
    var wantedIngredients: [KitchenIngredient] {
        let open = queue.waiting.flatMap(\.openItems).filter(\.preparation.isChefWork)
        return open.removingOneOfEach(pots.values.compactMap(\.ingredient))
    }

    var bubbles: [FloatingBubble?] { rack.slots }

    /// Five bubbles at most on screen: raw ones, plus one for each pot in
    /// use, since what's in it ends up as a bubble.
    private func refreshBubbles() {
        let potsInUse = pots.values.filter { !$0.isEmpty }.count
        rack.refill(wanted: wantedIngredients, limit: BubblePicker.slotCount - potsInUse)
    }
}
