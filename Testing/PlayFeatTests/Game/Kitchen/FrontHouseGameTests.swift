//
//  FrontHouseGameTests.swift
//  PlayFeatTests
//
//  A Front House shift without a camera: the floating dishes, the clean-tray
//  inventory, each compartment's rule, the dispenser, and the order's whole
//  lifecycle — served, eating, dirty tray back to Procurement, and only then
//  complete.
//

import CoreFoundation
import Testing
@testable import PlayFeat

@MainActor
struct FrontHouseGameTests {
    private static let full: [KitchenIngredient] = [.starJelly, .glowingMushroom, .coralLettuce, .tentacle]

    /// A playtest shift dealing `orders` in turn, round and round.
    private func makeGame(_ orders: [KitchenOrder], cleanTrays: Int = 3,
                          mode: KitchenMode = .playtest) -> FrontHouseGame {
        FrontHouseGame(mode: mode, wallTime: 0, crew: KitchenCrew(cleanTrays: cleanTrays, dirtyTrays: 0)) {
            let order = orders[$0 % orders.count]
            return KitchenOrder(id: $0, items: order.items, needsDrink: order.needsDrink)
        }
    }

    private func order(_ items: [KitchenIngredient], drink: Bool = false) -> KitchenOrder {
        KitchenOrder(id: 0, items: items, needsDrink: drink)
    }

    /// Runs the shift clock from `start` for `seconds`; returns where it got to.
    @discardableResult
    private func play(_ game: FrontHouseGame, from start: Double, for seconds: Double) -> Double {
        var wall = start
        while wall < start + seconds {
            wall += 0.2
            game.tick(wallTime: wall)
        }
        return wall
    }

    /// Plays until `count` more orders have arrived; returns the time.
    @discardableResult
    private func waitForOrders(_ count: Int, in game: FrontHouseGame) -> Double {
        play(game, from: 0, for: Double(count) * OrderQueue.arrivalInterval + 0.1)
    }

    private func dish(_ ingredient: KitchenIngredient, in game: FrontHouseGame) throws -> CarriedItem {
        .dish(ingredient, slot: try #require(game.bubbles.firstIndex { $0?.ingredient == ingredient }))
    }

    /// Sets a clean tray down and puts every dish of the active order on it.
    private func assemble(_ game: FrontHouseGame) throws {
        game.drop(.cleanTray, at: .assemblyTray)
        for item in try #require(game.queue.active).items {
            game.drop(try dish(item, in: game), at: .compartment(item.trayCompartment))
        }
    }

    private func pourAGlass(_ game: FrontHouseGame, from start: Double) -> Double {
        game.openDispenser()
        game.openTap()
        let poured = play(game, from: start, for: FrontHouseGame.pourTime + 0.2)
        game.closeTap()
        return play(game, from: poured, for: FrontHouseGame.finishedBeat + 0.2)
    }

    // MARK: - Floating dishes

    @Test func fiveBubblesTheActiveOrdersFirstThenTheNext() {
        let game = makeGame([order(Self.full), order([.bubbleTuber, .starJelly])])
        #expect(game.bubbles.map { $0?.ingredient } == Self.full + [nil], "the next isn't here yet")
        waitForOrders(1, in: game)
        #expect(game.bubbles.map { $0?.ingredient } == Self.full + [.bubbleTuber])
        #expect(game.bubbles.compactMap { $0 }.count == BubblePicker.slotCount)
    }

    /// A dish on the tray isn't supplied again; the freed bubble looks ahead.
    @Test func aPlacedDishIsReplacedByTheNextOrdersDish() throws {
        let game = makeGame([order(Self.full), order([.bubbleTuber, .starJelly])])
        waitForOrders(1, in: game)
        game.drop(.cleanTray, at: .assemblyTray)
        let before = game.bubbles
        let used = try #require(game.bubbles.firstIndex { $0?.ingredient == .coralLettuce })

        game.drop(.dish(.coralLettuce, slot: used), at: .compartment(.soup))

        #expect(game.tray?.dishes[.soup] == .coralLettuce)
        #expect(game.bubbles[used]?.ingredient == .starJelly)
        for index in before.indices where index != used {
            #expect(game.bubbles[index] == before[index])
        }
    }

    /// A bubble let go away from every target stays there, until it's used.
    @Test func aDishCanBeLeftAnywhere() throws {
        let game = makeGame([order(Self.full)])
        let item = try dish(.coralLettuce, in: game)
        game.place(item, at: CGPoint(x: 0.5, y: 0.6))
        #expect(game.bubbleSpots[item] == CGPoint(x: 0.5, y: 0.6))

        game.drop(.cleanTray, at: .assemblyTray)
        game.drop(item, at: .compartment(.soup))
        #expect(game.bubbleSpots[item] == nil)
    }

    /// Five dish bubbles, and the glass on top of them.
    @Test func fiveDishBubblesPlusTheGlass() {
        let game = makeGame([order(Self.full, drink: true), order([.bubbleTuber, .starJelly])])
        let arrived = waitForOrders(1, in: game)
        #expect(game.bubbles.compactMap { $0 }.count == BubblePicker.slotCount)
        _ = pourAGlass(game, from: arrived)
        #expect(game.isDrinkReady)
        #expect(game.bubbles.compactMap { $0 }.count == BubblePicker.slotCount)
    }

    @Test func theGlassCanBeLeftAnywhere() {
        let game = makeGame([order(Self.full, drink: true)])
        _ = pourAGlass(game, from: 0)
        game.place(.drink, at: CGPoint(x: 0.3, y: 0.4))
        #expect(game.bubbleSpots[.drink] == CGPoint(x: 0.3, y: 0.4))
    }

    // MARK: - Clean trays

    @Test func aCleanTrayIsTakenFromTheInventoryOnce() {
        let game = makeGame([order(Self.full)])
        #expect(game.accepts(.dish(.starJelly, slot: 0), at: .compartment(.dessert)) == false)

        game.drop(.cleanTray, at: .assemblyTray)
        #expect(game.crew.cleanTrays == 2)
        #expect(game.tray == ServingTray())

        game.drop(.cleanTray, at: .assemblyTray)
        #expect(game.crew.cleanTrays == 2, "only one tray on the counter at a time")
    }

    @Test func noCleanTrayNoAssembly() {
        let game = makeGame([order(Self.full)], cleanTrays: 0)
        #expect(!game.accepts(.cleanTray, at: .assemblyTray))
    }

    // MARK: - Compartments

    /// Each finished dish goes only in its own compartment.
    @Test(arguments: Self.full)
    func aDishOnlyGoesInItsOwnCompartment(ingredient: KitchenIngredient) throws {
        let game = makeGame([order(Self.full)])
        game.drop(.cleanTray, at: .assemblyTray)
        let item = try dish(ingredient, in: game)
        for compartment in TrayCompartment.allCases where compartment != ingredient.trayCompartment {
            #expect(!game.accepts(item, at: .compartment(compartment)), "\(ingredient) in \(compartment)")
        }
        #expect(game.accepts(item, at: .compartment(ingredient.trayCompartment)))
    }

    /// Raw ingredients aren't dishes: an unchopped mushroom or uncooked
    /// lettuce never goes on the tray.
    @Test func rawIngredientsAreRefused() {
        let game = makeGame([order(Self.full)])
        game.drop(.cleanTray, at: .assemblyTray)
        #expect(!game.accepts(.ingredient(.glowingMushroom, cardSlot: 1), at: .compartment(.vegetable)))
        #expect(!game.accepts(.ingredient(.coralLettuce, cardSlot: 2), at: .compartment(.soup)))
    }

    @Test func aFilledCompartmentTakesNothingMore() throws {
        let game = makeGame([order([.starJelly, .coralLettuce]), order([.starJelly, .tentacle])])
        waitForOrders(1, in: game)
        game.drop(.cleanTray, at: .assemblyTray)
        game.drop(try dish(.starJelly, in: game), at: .compartment(.dessert))
        #expect(!game.accepts(try dish(.starJelly, in: game), at: .compartment(.dessert)))
    }

    // MARK: - The dispenser

    @Test func aGlassIsOnlyDoneWhenFullAndTheTapClosed() {
        let game = makeGame([order(Self.full, drink: true)])
        game.openDispenser()
        #expect(game.station == .pouring)

        game.openTap()
        var clock = play(game, from: 0, for: 1)
        game.closeTap()
        #expect(!game.isDrinkReady, "half a glass isn't done")
        #expect(game.station == .pouring)

        game.openTap()
        clock = play(game, from: clock, for: FrontHouseGame.pourTime)
        #expect(game.fill == 1)
        #expect(!game.isDrinkReady, "full, but the tap is still open")
        game.closeTap()
        #expect(game.isDrinkReady)

        play(game, from: clock, for: FrontHouseGame.finishedBeat + 0.2)
        #expect(game.station == .counter)
        #expect(!game.canOpenDispenser, "one glass at a time")
    }

    /// The drink is served on its own, straight to the ticket, and never
    /// on the tray. Alone it doesn't serve the order.
    @Test func theDrinkCanBeServedBeforeTheTray() throws {
        let game = makeGame([order([.starJelly, .coralLettuce], drink: true), order([.tentacle])])
        let first = try #require(game.queue.active)
        let clock = pourAGlass(game, from: 0)
        try assemble(game)
        #expect(!game.accepts(.drink, at: .assemblyTray))
        #expect(try #require(game.tray).isComplete(for: first), "the tray doesn't wait for the drink")

        game.drop(.drink, at: .ticket(0))
        #expect(game.queue.active?.isDrinkServed == true)
        #expect(game.queue.active?.id == first.id, "still waiting for its tray")
        #expect(!game.isDrinkReady)

        game.drop(.servingTray(try #require(game.tray)), at: .ticket(0))
        #expect(game.queue.orders[0].stage == .eating)
        #expect(game.queue.active?.id != first.id)
        play(game, from: clock, for: FrontHouseGame.eatTime + 0.5)
        #expect(game.queue.orders[0].stage == .finishedEating)
    }

    /// With the tray served and the drink still owed, the order stays
    /// active and on the clock; the drink completes it.
    @Test func theDrinkCanBeServedAfterTheTray() throws {
        let game = makeGame([order([.starJelly, .coralLettuce], drink: true), order([.tentacle])])
        let first = game.queue.active?.id
        try assemble(game)
        game.drop(.servingTray(try #require(game.tray)), at: .ticket(0))
        #expect(game.queue.active?.id == first, "not served without its drink")
        #expect(game.queue.active?.isTrayServed == true)
        #expect(game.queue.active?.stage == .waiting)
        #expect(game.tray == nil)

        let clock = pourAGlass(game, from: 0)
        game.drop(.drink, at: .ticket(0))
        #expect(game.queue.orders[0].stage == .eating)
        #expect(game.queue.active?.id != first, "served, it's no longer the active order")
        play(game, from: clock, for: FrontHouseGame.eatTime + 0.5)
        #expect(game.queue.orders[0].stage == .finishedEating)
    }

    /// An order whose tray is served (its drink still owed) takes no second
    /// tray; the same tray can go to another order that wants it.
    @Test func aServedTrayIsServedOnce() throws {
        let game = makeGame([order([.starJelly, .coralLettuce], drink: true), order([.starJelly, .coralLettuce])])
        waitForOrders(1, in: game)
        try assemble(game)
        game.drop(.servingTray(try #require(game.tray)), at: .ticket(0))
        try assemble(game)
        let second = try #require(game.tray)
        #expect(!game.accepts(.servingTray(second), at: .ticket(0)))
        #expect(game.accepts(.servingTray(second), at: .ticket(1)))
    }

    /// Running out of time with only the tray served still costs a life, and
    /// the served tray goes back to be washed.
    @Test func anOrderWaitingForItsDrinkStillExpires() throws {
        let game = makeGame([order([.starJelly, .coralLettuce], drink: true)], cleanTrays: 1)
        try assemble(game)
        game.drop(.servingTray(try #require(game.tray)), at: .ticket(0))
        play(game, from: 0, for: OrderQueue.timeLimit + 0.5)
        #expect(game.shift.lives == KitchenShift.startingLives - 1)
        #expect(game.crew.dirtyTrays == 1)
    }

    @Test func noDrinkForAnOrderThatDoesNotWantOne() throws {
        let game = makeGame([order([.starJelly, .coralLettuce])])
        _ = pourAGlass(game, from: 0)
        #expect(!game.accepts(.drink, at: .ticket(0)))
    }

    // MARK: - Serving, eating and the dirty tray

    @Test func onlyACompleteTrayCanBeServed() throws {
        let game = makeGame([order([.starJelly, .coralLettuce])])
        game.drop(.cleanTray, at: .assemblyTray)
        game.drop(try dish(.starJelly, in: game), at: .compartment(.dessert))
        #expect(!game.accepts(.servingTray(try #require(game.tray)), at: .ticket(0)))
    }

    /// The whole lifecycle: serving keeps the order in its place, eating, and
    /// makes the next one active at once. Once the dirty tray is back the
    /// order is complete and leaves the rail, exactly once.
    @Test func servingEatingAndTheDirtyTrayCompleteTheOrder() throws {
        let game = makeGame([order([.starJelly, .coralLettuce]), order([.tentacle, .bubbleTuber])])
        let arrived = waitForOrders(1, in: game)
        let ids = game.queue.orders.map(\.id)
        try assemble(game)

        game.drop(.servingTray(try #require(game.tray)), at: .ticket(0))
        #expect(game.queue.orders[0].stage == .eating)
        #expect(game.queue.active?.id == ids[1], "the next order is active straight away")
        #expect(game.queue.orders.map(\.id) == ids)
        #expect(game.tray == nil)
        #expect(game.shift.ordersServed == 0)
        #expect(!game.accepts(.dirtyTray, at: .procurementPortal), "still eating")

        let clock = play(game, from: arrived, for: FrontHouseGame.eatTime + 0.5)
        #expect(game.queue.orders[0].stage == .finishedEating)
        #expect(!game.accepts(.dirtyTray, at: .assemblyTray))

        game.drop(.dirtyTray, at: .procurementPortal)
        #expect(game.shift.ordersServed == 1)
        #expect(game.crew.dirtyTrays == 1)
        #expect(game.queue.orders.map(\.id) == [ids[1]])
        #expect(!game.accepts(.dirtyTray, at: .procurementPortal), "returned once")

        play(game, from: clock, for: 1)
        #expect(game.shift.ordersServed == 1)
    }

    /// Any waiting order can be picked: a tray built for the second ticket
    /// serves it, and the first keeps waiting.
    @Test func anyWaitingOrderCanBeServed() throws {
        let game = makeGame([order([.starJelly, .coralLettuce]), order([.glowingMushroom, .tentacle])])
        waitForOrders(1, in: game)
        let first = game.queue.orders[0].id
        game.drop(.cleanTray, at: .assemblyTray)
        game.drop(try dish(.glowingMushroom, in: game), at: .compartment(.vegetable))
        game.drop(try dish(.tentacle, in: game), at: .compartment(.main))
        let tray = try #require(game.tray)

        #expect(!game.accepts(.servingTray(tray), at: .ticket(0)), "not what the first order wants")
        game.drop(.servingTray(tray), at: .ticket(1))
        #expect(game.queue.orders[1].stage == .eating)
        #expect(game.queue.active?.id == first)
    }

    /// A tray only takes dishes that still add up to some order.
    @Test func aTrayOnlyTakesDishesThatFitOneOrder() throws {
        let game = makeGame([order([.starJelly, .coralLettuce]), order([.glowingMushroom, .tentacle])])
        waitForOrders(1, in: game)
        game.drop(.cleanTray, at: .assemblyTray)
        game.drop(try dish(.starJelly, in: game), at: .compartment(.dessert))
        #expect(!game.accepts(try dish(.tentacle, in: game), at: .compartment(.main)))
        #expect(game.accepts(try dish(.coralLettuce, in: game), at: .compartment(.soup)))
    }

    /// The customer eats for `eatTime`, not longer.
    @Test func eatingTakesThreeSeconds() throws {
        let game = makeGame([order([.starJelly, .coralLettuce])])
        try assemble(game)
        game.drop(.servingTray(try #require(game.tray)), at: .ticket(0))

        let clock = play(game, from: 0, for: FrontHouseGame.eatTime - 0.5)
        #expect(game.queue.orders[0].stage == .eating)
        play(game, from: clock, for: 1)
        #expect(game.queue.orders[0].stage == .finishedEating)
    }

    /// Each order's clock runs from its own arrival: serving another one
    /// never gives it more time.
    @Test func servingDoesNotResetAnotherOrdersClock() throws {
        let game = makeGame([order([.starJelly, .coralLettuce])])
        let arrived = waitForOrders(1, in: game)
        try assemble(game)
        game.drop(.servingTray(try #require(game.tray)), at: .ticket(0))
        let second = try #require(game.queue.active)
        #expect(second.arrivedAt == OrderQueue.arrivalInterval)

        play(game, from: arrived, for: OrderQueue.arrivalInterval + OrderQueue.timeLimit + 0.5 - arrived)
        #expect(game.shift.lives == KitchenShift.startingLives - 1)
        #expect(!game.queue.orders.contains { $0.id == second.id })
    }

    /// An order runs out while another is eating: the expired one leaves,
    /// the served one keeps its place.
    @Test func anExpiredOrderLeavesTheServedOneOnTheTable() throws {
        let game = makeGame([order([.starJelly, .coralLettuce])])
        let arrived = waitForOrders(1, in: game)
        let ids = game.queue.orders.map(\.id)
        try assemble(game)
        game.drop(.servingTray(try #require(game.tray)), at: .ticket(0))

        play(game, from: arrived, for: OrderQueue.arrivalInterval + OrderQueue.timeLimit + 0.5 - arrived)
        #expect(game.shift.lives == KitchenShift.startingLives - 1)
        #expect(game.queue.orders.map(\.id) == [ids[0], ids[1] + 1])
        #expect(game.queue.orders[0].stage == .finishedEating)
    }

    /// All three orders can be served. A full rail takes no new order, even
    /// with nothing left to work on; a tray going back opens a place, and
    /// the next order arrives a fresh 20 seconds later.
    @Test func aFullRailWaitsForADirtyTrayToGoBack() throws {
        let game = makeGame([order([.starJelly, .coralLettuce])], cleanTrays: 4)
        var clock = waitForOrders(2, in: game)
        for ticket in 0..<OrderQueue.capacity {
            try assemble(game)
            game.drop(.servingTray(try #require(game.tray)), at: .ticket(ticket))
        }
        #expect(game.traysOnTable == 3)
        #expect(game.queue.active == nil)

        clock = play(game, from: clock, for: OrderQueue.timeLimit)
        #expect(game.queue.orders.count == 3)
        #expect(game.shift.lives == KitchenShift.startingLives, "served orders are safe")

        game.drop(.dirtyTray, at: .procurementPortal)
        clock = play(game, from: clock, for: OrderQueue.arrivalInterval - 1)
        #expect(game.queue.orders.count == 2)
        play(game, from: clock, for: 1.5)
        #expect(game.queue.orders.count == 3)
    }

    /// Playtest: the stand-in Procurement washes a returned tray and it comes
    /// back to the stand.
    @Test func aReturnedTrayComesBackCleanInThePlaytest() throws {
        let game = makeGame([order([.starJelly, .coralLettuce])])
        try assemble(game)
        game.drop(.servingTray(try #require(game.tray)), at: .ticket(0))
        var clock = play(game, from: 0, for: FrontHouseGame.eatTime + 0.5)
        game.drop(.dirtyTray, at: .procurementPortal)
        #expect(game.crew.cleanTrays == 2)

        clock = play(game, from: clock, for: FrontHouseGame.washTime + 0.5)
        #expect(game.crew.cleanTrays == 3)
        #expect(game.crew.dirtyTrays == 0)
        play(game, from: clock, for: FrontHouseGame.washTime)
        #expect(game.crew.cleanTrays == 3, "counted once")
    }

    @Test func inMultiplayerProcurementWashesTheTrays() throws {
        let game = makeGame([order([.starJelly, .coralLettuce])], mode: .multiplayer)
        try assemble(game)
        game.drop(.servingTray(try #require(game.tray)), at: .ticket(0))
        let clock = play(game, from: 0, for: FrontHouseGame.eatTime + 0.5)
        game.drop(.dirtyTray, at: .procurementPortal)

        play(game, from: clock, for: FrontHouseGame.washTime + 0.5)
        #expect(game.crew.cleanTrays == 2)
        #expect(game.crew.dirtyTrays == 1)
    }

    /// An order that runs out while waiting costs a life. If what was on the
    /// counter tray fits no other order it goes; the tray stays.
    @Test func anExpiredOrderEmptiesATrayNothingElseWants() throws {
        let other = order([.glowingMushroom, .tentacle])
        let game = makeGame([order([.starJelly, .coralLettuce]), other, other])
        game.drop(.cleanTray, at: .assemblyTray)
        game.drop(try dish(.starJelly, in: game), at: .compartment(.dessert))

        play(game, from: 0, for: OrderQueue.timeLimit + 1)
        #expect(game.shift.lives == KitchenShift.startingLives - 1)
        #expect(game.tray == ServingTray())
        #expect(game.crew.cleanTrays == 2)
    }

    /// A tray another waiting order could still use keeps its dishes.
    @Test func anExpiredOrdersTrayIsKeptForAnotherOrder() throws {
        let game = makeGame([order([.starJelly, .coralLettuce])])
        game.drop(.cleanTray, at: .assemblyTray)
        game.drop(try dish(.starJelly, in: game), at: .compartment(.dessert))

        play(game, from: 0, for: OrderQueue.timeLimit + 1)
        #expect(game.tray?.dishes == [.dessert: .starJelly])
    }

    // MARK: - Orders

    /// Random orders fit one tray: one dish per compartment.
    @Test func randomOrdersFillEachCompartmentAtMostOnce() {
        for id in 0..<200 {
            let compartments = KitchenOrder.random(id: id).items.map(\.trayCompartment)
            #expect(Set(compartments).count == compartments.count)
        }
    }
}
