//
//  ProcurementGame.swift
//  PlayFeat
//
//  Runs a Procurement shift: the three ingredient cards, the cutting board,
//  the sink and the trays, on top of the shared `KitchenShift` (orders,
//  clock, lives, score). The single source of truth the SwiftUI HUD and
//  ProcurementScene read. Chef and Front House are played by `KitchenCrew`.
//

import Foundation
import QuartzCore

@Observable
final class ProcurementGame {

    /// Where the player is working. The cutting board and the sink each open
    /// a zoomed-in panel that takes over the worktop until the job is done.
    enum Station: Equatable {
        case worktop
        case cutting(KitchenIngredient)
        case washing
    }

    static let startingLives = KitchenShift.startingLives
    /// Matches the three-segment bar and the three cut stages in the art.
    static let chopsNeeded = 3
    static let circlesNeeded = 3.0
    /// How long a finished cut or wash stays on screen before its panel closes.
    static let finishedBeat: TimeInterval = 0.9

    // MARK: - State

    let shift: KitchenShift
    private(set) var station: Station = .worktop
    private(set) var cards: [KitchenIngredient]
    private(set) var crew: KitchenCrew

    /// A sliced ingredient waiting on the board for the Front House portal.
    private(set) var slicedOnBoard: KitchenIngredient?
    private(set) var chops = 0
    /// 0...1 through scrubbing the tray in the sink.
    private(set) var washProgress = 0.0
    /// Trays washed so far. Each one floats off to Front House by itself;
    /// the count is only there for the worktop to animate it.
    private(set) var traysWashed = 0
    /// The player's own work this shift, for the shift report.
    private(set) var report = ShiftReport(role: .procurement)
    /// Dirty trays a hand has taken out of the bubble, so it isn't also
    /// drawn there.
    private(set) var dirtyTraysInHand = 0
    /// Cards and sliced ingredients the player let go of away from any
    /// target, where they were left (fractions of the screen). They still
    /// count as the card or the board's until they're used.
    private(set) var bubbleSpots: [CarriedItem: CGPoint] = [:]
    /// What hands are carrying, so the worktop doesn't also draw it in place.
    private(set) var itemsInHand: [CarriedItem] = []

    @ObservationIgnored private var stationFinishedAt: TimeInterval?

    init(mode: KitchenMode,
         wallTime: TimeInterval = CACurrentMediaTime(),
         crew: KitchenCrew = KitchenCrew(),
         makeOrder: @escaping (Int) -> KitchenOrder = KitchenOrder.random) {
        let shift = KitchenShift(mode: mode, wallTime: wallTime, makeOrder: makeOrder)
        self.shift = shift
        self.crew = crew
        cards = IngredientCardPicker.deal(current: shift.queue.active.items,
                                          upcoming: shift.queue.upcoming.flatMap(\.items))
        shift.onTick = { [weak self] in self?.tick(wallTime: $0) }
    }

    // MARK: - The shared shift

    var mode: KitchenMode { shift.mode }
    var queue: OrderQueue { shift.queue }
    var lives: Int { shift.lives }
    var ordersServed: Int { shift.ordersServed }
    var isOver: Bool { shift.isOver }
    var elapsedSeconds: Int { shift.elapsedSeconds }
    var isActiveOrderRunningLow: Bool { shift.isActiveOrderRunningLow }
    /// Seconds of play, for views that animate against the order clock.
    var now: TimeInterval { shift.now }
    var activeFractionLeft: CGFloat { shift.activeFractionLeft }

    /// One step of the shift. Internal so tests can drive the clock.
    func tick(wallTime: TimeInterval) {
        guard !isOver else { return }
        shift.advanceClock(to: wallTime)
        crew.update(at: now)
        closeFinishedStation()
        settleActiveOrder()
    }

    // MARK: - Dropping things

    /// Whether letting go of `item` over `zone` does something. Anything it
    /// doesn't accept goes back where it was picked up.
    func accepts(_ item: CarriedItem, at zone: DropZone) -> Bool {
        guard station == .worktop, !isOver else { return false }
        switch (item, zone) {
        case let (.ingredient(ingredient, slot), _) where !isCard(ingredient, at: slot):
            return false
        case (.ingredient, .trash), (.sliced, .trash):
            return true
        case let (.ingredient(ingredient, _), .cuttingBoard):
            return ingredient.preparation == .chop && slicedOnBoard == nil
        case let (.ingredient(ingredient, _), portal) where portal.isPortal:
            return delivery(of: ingredient, sliced: false, to: portal) != nil
        case let (.sliced(ingredient), portal) where portal.isPortal:
            return slicedOnBoard == ingredient && delivery(of: ingredient, sliced: true, to: portal) != nil
        case (.dirtyTray, .sink):
            return crew.dirtyTrays > 0
        default:
            return false
        }
    }

    func pickUp(_ item: CarriedItem) {
        if item == .dirtyTray { dirtyTraysInHand += 1 }
        itemsInHand.append(item)
    }

    /// A carried item went back where it came from, or was used.
    func putBack(_ item: CarriedItem) {
        if item == .dirtyTray { dirtyTraysInHand = max(0, dirtyTraysInHand - 1) }
        if let index = itemsInHand.firstIndex(of: item) { itemsInHand.remove(at: index) }
    }

    /// A card or sliced ingredient let go away from any target stays there.
    func place(_ item: CarriedItem, at spot: CGPoint) {
        switch item {
        case .ingredient, .sliced: bubbleSpots[item] = spot
        default: break
        }
    }

    /// Lets go of `item` over `zone`. Does nothing unless `accepts` agrees, so
    /// a tray can't be handed over twice.
    func drop(_ item: CarriedItem, at zone: DropZone) {
        guard accepts(item, at: zone) else { return }
        putBack(item)
        bubbleSpots[item] = nil
        switch item {
        case let .ingredient(ingredient, slot):
            use(ingredient, sliced: false, at: zone)
            replaceCard(at: slot)
        case let .sliced(ingredient):
            slicedOnBoard = nil
            use(ingredient, sliced: true, at: zone)
        case .dirtyTray:
            crew.takeDirtyTray()
            washProgress = 0
            station = .washing
        case .cleanTray, .cooked, .dish, .drink, .servingTray:
            break  // other roles'; `accepts` never lets one through here
        }
        settleActiveOrder()
    }

    private func use(_ ingredient: KitchenIngredient, sliced: Bool, at zone: DropZone) {
        switch zone {
        case .cuttingBoard:
            chops = 0
            station = .cutting(ingredient)
        case .kitchenPortal, .frontHousePortal:
            deliver(ingredient, sliced: sliced, to: zone)
        default:
            break
        }
    }

    // MARK: - Delivery

    /// The one check every portal uses: which of the active order's
    /// requirements `ingredient` fills if handed over through `portal`, or
    /// nil when it doesn't count — the wrong portal for it, not prepared yet
    /// (a mushroom must be sliced first), or nothing on the active order is
    /// still waiting for it. With two of the same ingredient on a ticket it is
    /// always the next one still open.
    func delivery(of ingredient: KitchenIngredient, sliced: Bool, to portal: DropZone) -> Int? {
        guard portal == ingredient.deliveryPortal, sliced == ingredient.isDeliveredSliced else { return nil }
        return queue.active.nextOpenRequirement(for: ingredient)
    }

    /// Ticks the requirement off on the active order the moment the item goes
    /// through — no waiting for the Chef to cook or Front House to serve —
    /// and hands it to the crew to finish.
    private func deliver(_ ingredient: KitchenIngredient, sliced: Bool, to portal: DropZone) {
        guard let requirement = delivery(of: ingredient, sliced: sliced, to: portal) else { return }
        shift.markActiveRequirementDelivered(at: requirement)
        report.record(.ingredientSent)
        crew.receive(ingredient, at: now)
    }

    // MARK: - Processing gestures

    /// The cutting gesture recognized one chop.
    func registerChop() {
        guard case let .cutting(ingredient) = station, chops < Self.chopsNeeded else { return }
        chops += 1
        guard chops == Self.chopsNeeded else { return }
        slicedOnBoard = ingredient
        report.record(.ingredientCutOrTrayWashed)
        stationFinishedAt = now
    }

    /// The washing gesture recognized this many circles of scrubbing.
    func addScrub(circles: Double) {
        guard station == .washing, washProgress < 1, circles > 0 else { return }
        washProgress = min(1, washProgress + circles / Self.circlesNeeded)
        guard washProgress >= 1 else { return }
        traysWashed += 1
        report.record(.ingredientCutOrTrayWashed)
        crew.receiveCleanTray()
        stationFinishedAt = now
    }

    // MARK: - Rules

    /// What the active order still needs from Procurement: its items minus
    /// whatever is already cooking, waiting at Front House, or on the board.
    var currentNeeds: [KitchenIngredient] {
        var underway: [KitchenIngredient] = []
        if let slicedOnBoard { underway.append(slicedOnBoard) }
        if case let .cutting(ingredient) = station { underway.append(ingredient) }
        return queue.active.openItems.removingOneOfEach(underway)
    }

    private func isCard(_ ingredient: KitchenIngredient, at slot: Int) -> Bool {
        cards.indices.contains(slot) && cards[slot] == ingredient
    }

    /// Re-deals only the card that was used; the other two stay put.
    private func replaceCard(at slot: Int) {
        var others = cards
        others.remove(at: slot)
        cards[slot] = IngredientCardPicker.replacement(
            among: others,
            current: currentNeeds,
            upcoming: queue.upcoming.flatMap(\.items)
        )
    }

    private func closeFinishedStation() {
        guard let finishedAt = stationFinishedAt, now - finishedAt >= Self.finishedBeat else { return }
        stationFinishedAt = nil
        station = .worktop
    }

    /// A finished active order leaves the rail; one that runs out of time
    /// costs a life. Either way the next one moves up and a new one is dealt
    /// at the end.
    private func settleActiveOrder() {
        if shift.isActiveOrderFinished(isServed: crew.canServe(queue.active)) {
            completeActiveOrder()
        } else if shift.hasActiveOrderExpired {
            crew.discardDeliveries()
            shift.failActiveOrder()
        }
    }

    /// The playtest clears the order out at once; with all three roles Front
    /// House has served it on a tray.
    private func completeActiveOrder() {
        switch mode {
        case .playtest: crew.takeAway(queue.active, at: now)
        case .multiplayer: crew.serve(queue.active, at: now)
        }
        shift.completeActiveOrder()
    }
}
