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

    private func dish(_ ingredient: KitchenIngredient, in game: FrontHouseGame) throws -> CarriedItem {
        .dish(ingredient, slot: try #require(game.bubbles.firstIndex { $0?.ingredient == ingredient }))
    }

    /// Sets a clean tray down and puts every dish of the active order on it.
    private func assemble(_ game: FrontHouseGame) throws {
        game.drop(.cleanTray, at: .assemblyTray)
        for item in game.queue.active.items {
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
        #expect(game.bubbles.map { $0?.ingredient } == Self.full + [.bubbleTuber])
    }

    /// A dish on the tray isn't supplied again; the freed bubble looks ahead.
    @Test func aPlacedDishIsReplacedByTheNextOrdersDish() throws {
        let game = makeGame([order(Self.full), order([.bubbleTuber, .starJelly])])
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

    /// A dish the active order doesn't want waits, even in the right spot.
    @Test func aDishForALaterOrderIsRefused() throws {
        let game = makeGame([order([.starJelly, .coralLettuce]), order([.bubbleTuber, .starJelly])])
        game.drop(.cleanTray, at: .assemblyTray)
        #expect(!game.accepts(try dish(.bubbleTuber, in: game), at: .compartment(.main)))
    }

    @Test func aFilledCompartmentTakesNothingMore() throws {
        let game = makeGame([order([.starJelly, .coralLettuce]), order([.starJelly, .tentacle])])
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

    @Test func theDrinkGoesOnATrayWhoseOrderWantsOne() throws {
        let game = makeGame([order([.starJelly, .coralLettuce], drink: true)])
        _ = pourAGlass(game, from: 0)
        #expect(!game.accepts(.drink, at: .assemblyTray), "no tray yet")

        try assemble(game)
        #expect(!game.tray!.isComplete(for: game.queue.active), "still missing its drink")
        game.drop(.drink, at: .assemblyTray)

        #expect(game.tray?.hasDrink == true)
        #expect(!game.isDrinkReady)
        #expect(game.tray!.isComplete(for: game.queue.active))
    }

    @Test func noDrinkForAnOrderThatDoesNotWantOne() throws {
        let game = makeGame([order([.starJelly, .coralLettuce])])
        _ = pourAGlass(game, from: 0)
        try assemble(game)
        #expect(!game.accepts(.drink, at: .assemblyTray))
    }

    // MARK: - Serving, eating and the dirty tray

    @Test func onlyACompleteTrayCanBeServed() throws {
        let game = makeGame([order([.starJelly, .coralLettuce])])
        game.drop(.cleanTray, at: .assemblyTray)
        game.drop(try dish(.starJelly, in: game), at: .compartment(.dessert))
        #expect(!game.accepts(.servingTray(try #require(game.tray)), at: .activeOrder))
    }

    /// The whole lifecycle: serving keeps the order in its place, eating, and
    /// makes the next one active at once — but nothing new is dealt until the
    /// dirty tray is back; then the rail slides left and a new order arrives
    /// at the end, exactly once.
    @Test func servingEatingAndTheDirtyTrayCompleteTheOrder() throws {
        let game = makeGame([order([.starJelly, .coralLettuce]), order([.tentacle, .bubbleTuber])])
        let ids = game.queue.orders.map(\.id)
        try assemble(game)

        game.drop(.servingTray(try #require(game.tray)), at: .activeOrder)
        #expect(game.queue.orders[0].stage == .eating)
        #expect(game.queue.active.id == ids[1], "the next order is active straight away")
        #expect(game.queue.orders.map(\.id) == ids, "no new order yet")
        #expect(game.tray == nil)
        #expect(game.shift.ordersServed == 0)
        #expect(!game.accepts(.dirtyTray, at: .procurementPortal), "still eating")

        let clock = play(game, from: 0, for: FrontHouseGame.eatTime + 0.5)
        #expect(game.queue.orders[0].stage == .finishedEating)
        #expect(game.queue.orders.map(\.id) == ids, "still no new order")
        #expect(!game.accepts(.dirtyTray, at: .assemblyTray))

        game.drop(.dirtyTray, at: .procurementPortal)
        #expect(game.shift.ordersServed == 1)
        #expect(game.crew.dirtyTrays == 1)
        #expect(game.queue.orders.map(\.id) == Array(ids.dropFirst()) + [ids.last! + 1])
        #expect(game.queue.active.id == ids[1])
        #expect(!game.accepts(.dirtyTray, at: .procurementPortal), "returned once")

        play(game, from: clock, for: 1)
        #expect(game.shift.ordersServed == 1)
    }

    /// The customer eats for `eatTime`, not longer.
    @Test func eatingTakesThreeSeconds() throws {
        let game = makeGame([order([.starJelly, .coralLettuce])])
        try assemble(game)
        game.drop(.servingTray(try #require(game.tray)), at: .activeOrder)

        let clock = play(game, from: 0, for: FrontHouseGame.eatTime - 0.5)
        #expect(game.queue.orders[0].stage == .eating)
        play(game, from: clock, for: 1)
        #expect(game.queue.orders[0].stage == .finishedEating)
    }

    /// Serving hands the clock to the next order with its full time; the
    /// served one can't run out any more.
    @Test func servingStartsTheNextOrdersClock() throws {
        let game = makeGame([order([.starJelly, .coralLettuce])])
        let clock = play(game, from: 0, for: OrderQueue.timeLimit - 5)
        try assemble(game)
        game.drop(.servingTray(try #require(game.tray)), at: .activeOrder)
        #expect(game.shift.activeFractionLeft == 1)

        play(game, from: clock, for: 30)
        #expect(game.shift.lives == KitchenShift.startingLives)
        #expect(game.queue.orders[0].stage == .finishedEating)
    }

    /// The active order runs out while another is eating: the expired one
    /// leaves, the eating one keeps its place.
    @Test func anExpiredOrderLeavesTheServedOneOnTheTable() throws {
        let game = makeGame([order([.starJelly, .coralLettuce])])
        let ids = game.queue.orders.map(\.id)
        try assemble(game)
        game.drop(.servingTray(try #require(game.tray)), at: .activeOrder)

        play(game, from: 0, for: OrderQueue.timeLimit + 1)
        #expect(game.shift.lives == KitchenShift.startingLives - 1)
        #expect(game.queue.orders.map(\.id) == [ids[0], ids[2], ids[3], ids.last! + 1])
        #expect(game.queue.orders[0].stage == .finishedEating)
    }

    /// Two trays on the table at most, so the active ticket stays on the rail.
    @Test func atMostTwoTraysOnTheTable() throws {
        let game = makeGame([order([.starJelly, .coralLettuce])], cleanTrays: 3)
        for _ in 0..<FrontHouseGame.tableSeats {
            try assemble(game)
            game.drop(.servingTray(try #require(game.tray)), at: .activeOrder)
        }
        try assemble(game)
        #expect(!game.accepts(.servingTray(try #require(game.tray)), at: .activeOrder))
    }

    /// Playtest: the stand-in Procurement washes a returned tray and it comes
    /// back to the stand.
    @Test func aReturnedTrayComesBackCleanInThePlaytest() throws {
        let game = makeGame([order([.starJelly, .coralLettuce])])
        try assemble(game)
        game.drop(.servingTray(try #require(game.tray)), at: .activeOrder)
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
        game.drop(.servingTray(try #require(game.tray)), at: .activeOrder)
        let clock = play(game, from: 0, for: FrontHouseGame.eatTime + 0.5)
        game.drop(.dirtyTray, at: .procurementPortal)

        play(game, from: clock, for: FrontHouseGame.washTime + 0.5)
        #expect(game.crew.cleanTrays == 2)
        #expect(game.crew.dirtyTrays == 1)
    }

    /// An order that runs out while waiting costs a life; what was on its
    /// tray goes, the tray stays.
    @Test func anExpiredOrderEmptiesTheTray() throws {
        let game = makeGame([order([.starJelly, .coralLettuce])])
        game.drop(.cleanTray, at: .assemblyTray)
        game.drop(try dish(.starJelly, in: game), at: .compartment(.dessert))

        play(game, from: 0, for: OrderQueue.timeLimit + 1)
        #expect(game.shift.lives == KitchenShift.startingLives - 1)
        #expect(game.tray == ServingTray())
        #expect(game.crew.cleanTrays == 2)
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
