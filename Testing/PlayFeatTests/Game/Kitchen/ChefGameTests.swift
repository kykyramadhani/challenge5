//
//  ChefGameTests.swift
//  PlayFeatTests
//
//  A Chef shift without a camera: the five floating bubbles and their
//  replacements, the three stations and their rules, soup that only cooks
//  when stirred, and dishes that only count once they go through the Front
//  House portal.
//

import CoreGraphics
import Testing
@testable import PlayFeat

@MainActor
struct ChefGameTests {
    /// A playtest shift dealing `orders` in turn, round and round.
    private func makeGame(_ orders: [[KitchenIngredient]], mode: KitchenMode = .playtest) -> ChefGame {
        ChefGame(mode: mode, wallTime: 0) { KitchenOrder(id: $0, items: orders[$0 % orders.count]) }
    }

    /// Runs the shift clock forward in steps the play clock credits in full.
    private func play(_ game: ChefGame, from start: Double = 0, for seconds: Double) {
        var wall = start
        while wall < start + seconds {
            wall += 0.2
            game.tick(wallTime: wall)
        }
    }

    /// Plays until `count` more orders have arrived; returns the time.
    @discardableResult
    private func waitForOrders(_ count: Int, in game: ChefGame) -> Double {
        let time = Double(count) * OrderQueue.arrivalInterval + 0.1
        play(game, for: time)
        return time
    }

    private func slot(of ingredient: KitchenIngredient, in game: ChefGame) throws -> Int {
        try #require(game.bubbles.firstIndex { $0?.ingredient == ingredient })
    }

    private func bubble(_ ingredient: KitchenIngredient, in game: ChefGame) throws -> CarriedItem {
        .ingredient(ingredient, cardSlot: try slot(of: ingredient, in: game))
    }

    private func kinds(_ game: ChefGame) -> [KitchenIngredient?] {
        game.bubbles.map { $0?.ingredient }
    }

    // MARK: - Floating bubbles

    /// Four bubbles for the active order's dishes, the fifth for the next.
    @Test func fiveBubblesFourForTheActiveOrderOneForTheNext() {
        let game = makeGame([[.bubbleTuber, .coralLettuce, .tentacle, .coralLettuce], [.tentacle, .bubbleTuber]])
        #expect(kinds(game) == [.bubbleTuber, .coralLettuce, .tentacle, .coralLettuce, nil], "the next isn't here yet")
        waitForOrders(1, in: game)
        #expect(kinds(game) == [.bubbleTuber, .coralLettuce, .tentacle, .coralLettuce, .tentacle])
    }

    /// Bubbles only ever stand for a dish some order still needs: with one
    /// tuber per order and three orders there are three, not five.
    @Test func neverMoreBubblesThanDishesNeeded() {
        let game = makeGame([[.bubbleTuber, .starJelly]])
        waitForOrders(2, in: game)
        #expect(kinds(game) == [.bubbleTuber, .bubbleTuber, .bubbleTuber, nil, nil])
    }

    /// What goes from Procurement straight to Front House never floats here,
    /// and in the playtest it's already ticked off.
    @Test func procurementOnlyItemsAreHandledByTheStandIn() {
        let game = makeGame([[.glowingMushroom, .bubbleTuber, .starJelly, .tentacle]])
        #expect(game.queue.active?.delivered == [0, 2])
        #expect(!kinds(game).contains(.glowingMushroom))
        #expect(!kinds(game).contains(.starJelly))
    }

    /// A used bubble is replaced in its own slot; the others keep their slot
    /// and identity.
    @Test func usingABubbleReplacesOnlyThatSlot() throws {
        let game = makeGame([[.bubbleTuber, .coralLettuce, .tentacle, .coralLettuce], [.tentacle, .bubbleTuber]])
        let before = game.bubbles
        let used = try slot(of: .bubbleTuber, in: game)

        game.drop(.ingredient(.bubbleTuber, cardSlot: used), at: .trash)

        let replacement = try #require(game.bubbles[used])
        #expect(replacement.id != before[used]?.id)
        for index in before.indices where index != used {
            #expect(game.bubbles[index] == before[index])
        }
    }

    /// The tuber in the pot covers the active order's tuber, so the new
    /// bubble looks ahead instead of supplying it twice.
    @Test func aDishInAPotIsNotSuppliedAgain() throws {
        let game = makeGame([[.bubbleTuber, .coralLettuce], [.tentacle, .tentacle]])
        game.drop(try bubble(.bubbleTuber, in: game), at: .boilingPot)

        let tubers = kinds(game).filter { $0 == .bubbleTuber }.count
        let wanted = game.wantedIngredients.filter { $0 == .bubbleTuber }.count
        #expect(tubers == wanted)
    }

    @Test func trashingABubbleSendsTheSameDishAgain() throws {
        let game = makeGame([[.tentacle, .starJelly]])
        let used = try slot(of: .tentacle, in: game)
        let oldID = game.bubbles[used]?.id

        game.drop(.ingredient(.tentacle, cardSlot: used), at: .trash)

        #expect(game.bubbles[used]?.ingredient == .tentacle)
        #expect(game.bubbles[used]?.id != oldID)
    }

    @Test func aBubbleThatIsNotInItsSlotIsRefused() throws {
        let game = makeGame([[.bubbleTuber, .coralLettuce]])
        let tuberSlot = try slot(of: .bubbleTuber, in: game)
        #expect(!game.accepts(.ingredient(.coralLettuce, cardSlot: tuberSlot), at: .brothPot))
        #expect(!game.accepts(.ingredient(.coralLettuce, cardSlot: 99), at: .brothPot))
    }

    /// Raw bubbles plus pots in use never pass five.
    @Test func atMostFiveBubblesCountingThePots() throws {
        let game = makeGame([[.bubbleTuber, .coralLettuce, .tentacle, .coralLettuce], [.tentacle, .bubbleTuber]])
        let arrived = waitForOrders(1, in: game)
        game.drop(try bubble(.tentacle, in: game), at: .fryer)
        #expect(game.bubbles.compactMap { $0 }.count == 4)
        play(game, from: arrived, for: ChefGame.fryTime + 0.5)
        #expect(game.readyDishCount == 1)
        #expect(game.bubbles.compactMap { $0 }.count == 4)
    }

    @Test func aRawBubbleCanBeLeftAnywhere() throws {
        let game = makeGame([[.tentacle, .starJelly]])
        let item = try bubble(.tentacle, in: game)
        game.place(item, at: CGPoint(x: 0.3, y: 0.4))
        #expect(game.bubbleSpots[item] == CGPoint(x: 0.3, y: 0.4))
        game.place(.dirtyTray, at: CGPoint(x: 0.3, y: 0.4))
        #expect(game.bubbleSpots[.dirtyTray] == nil, "trays don't float")
    }

    // MARK: - Stations

    /// Each raw ingredient has exactly one station, and never the portal.
    @Test(arguments: [
        (KitchenIngredient.bubbleTuber, DropZone.boilingPot),
        (.coralLettuce, .brothPot),
        (.tentacle, .fryer),
    ])
    func rawIngredientsOnlyGoToTheirOwnStation(ingredient: KitchenIngredient, station: DropZone) throws {
        let game = makeGame([[ingredient, ingredient]])
        let item = try bubble(ingredient, in: game)
        for zone in [DropZone.boilingPot, .brothPot, .fryer, .frontHousePortal] where zone != station {
            #expect(!game.accepts(item, at: zone), "\(ingredient) into \(zone)")
        }
        #expect(game.accepts(item, at: station))
    }

    @Test func aBusyPotTakesNothingMore() throws {
        let game = makeGame([[.bubbleTuber, .bubbleTuber]])
        game.drop(try bubble(.bubbleTuber, in: game), at: .boilingPot)
        #expect(!game.accepts(try bubble(.bubbleTuber, in: game), at: .boilingPot))
    }

    /// Boiling and frying run by themselves for their time, then the dish is
    /// ready — and only then can it go to Front House, exactly once.
    @Test(arguments: [
        (KitchenIngredient.bubbleTuber, DropZone.boilingPot, ChefGame.boilTime),
        (.tentacle, .fryer, ChefGame.fryTime),
    ])
    func boilingAndFryingFinishByThemselves(ingredient: KitchenIngredient, station: DropZone,
                                            time: Double) throws {
        let game = makeGame([[ingredient, .starJelly]])
        game.drop(try bubble(ingredient, in: game), at: station)
        play(game, for: time - 1)
        #expect(game.pots[station]?.readyIngredient == nil)
        #expect(!game.accepts(.cooked(ingredient), at: .frontHousePortal))

        play(game, from: time - 1, for: 1.5)
        #expect(game.pots[station] == .ready(ingredient))
        #expect(game.cookingProgress(in: station) == 1)

        let activeID = game.queue.active?.id
        game.drop(.cooked(ingredient), at: .frontHousePortal)
        #expect(game.pots[station] == .empty)
        #expect(game.queue.active?.id != activeID, "the order's last dish completes it")
        #expect(!game.accepts(.cooked(ingredient), at: .frontHousePortal))
    }

    /// Coral lettuce never cooks by itself: it opens the broth pot and only
    /// stirring makes it soup.
    @Test func soupNeedsStirring() throws {
        let game = makeGame([[.coralLettuce, .tentacle]])
        game.drop(try bubble(.coralLettuce, in: game), at: .brothPot)
        #expect(game.station == .stirring)
        #expect(game.pots[.brothPot] == .stirring(.coralLettuce))

        play(game, for: 20)
        #expect(game.pots[.brothPot] == .stirring(.coralLettuce))

        game.addStir(circles: 2)
        #expect(game.pots[.brothPot]?.readyIngredient == nil)
        game.addStir(circles: 1)
        #expect(game.pots[.brothPot] == .ready(.coralLettuce))
        #expect(game.stirProgress == 1)

        play(game, from: 20, for: 1)
        #expect(game.station == .kitchen)
    }

    /// Nothing else can be picked up or dropped while the pot is zoomed in.
    @Test func theKitchenWaitsWhileStirring() throws {
        let game = makeGame([[.coralLettuce, .tentacle]])
        game.drop(try bubble(.coralLettuce, in: game), at: .brothPot)
        #expect(!game.accepts(try bubble(.tentacle, in: game), at: .fryer))
    }

    // MARK: - Delivery and orders

    @Test func soupThroughFrontHouseTicksItsRequirement() throws {
        let game = makeGame([[.tentacle, .coralLettuce, .bubbleTuber, .glowingMushroom]])
        game.drop(try bubble(.coralLettuce, in: game), at: .brothPot)
        game.addStir(circles: 3)
        play(game, for: 1)

        game.drop(.cooked(.coralLettuce), at: .frontHousePortal)

        #expect(game.queue.active?.isDelivered(at: 1) == true)
        #expect(game.queue.active?.isDelivered(at: 0) == false)
        #expect(game.shift.ordersServed == 0)
    }

    /// Any waiting order can be worked on: a dish only the second order
    /// wants counts for it, and completes it.
    @Test func aDishForALaterOrderCountsForIt() throws {
        let game = makeGame([[.bubbleTuber, .bubbleTuber, .bubbleTuber, .bubbleTuber], [.tentacle, .starJelly]])
        let arrived = waitForOrders(1, in: game)
        let first = game.queue.orders[0].id
        game.drop(try bubble(.tentacle, in: game), at: .fryer)
        play(game, from: arrived, for: ChefGame.fryTime + 0.5)

        game.drop(.cooked(.tentacle), at: .frontHousePortal)
        #expect(game.shift.ordersServed == 1)
        #expect(game.queue.orders.map(\.id) == [first])
        #expect(game.delivery(of: .tentacle) == nil, "nothing else wants one")
    }

    /// Dishes sitting in pots, even cooked, don't finish an order.
    @Test func cookingAloneNeverCompletesAnOrder() throws {
        let game = makeGame([[.bubbleTuber, .tentacle]])
        game.drop(try bubble(.bubbleTuber, in: game), at: .boilingPot)
        game.drop(try bubble(.tentacle, in: game), at: .fryer)
        play(game, for: ChefGame.boilTime + 0.5)

        #expect(game.readyDishCount == 2)
        #expect(game.shift.ordersServed == 0)
    }

    /// Playtest: the last dish through the portal completes the order at
    /// once; the next order is active and the bubbles follow it.
    @Test func theLastDishCompletesTheOrderInThePlaytest() throws {
        let game = makeGame([[.bubbleTuber, .starJelly], [.tentacle, .glowingMushroom]])
        let arrived = waitForOrders(1, in: game)
        let ids = game.queue.orders.map(\.id)
        game.drop(try bubble(.bubbleTuber, in: game), at: .boilingPot)
        play(game, from: arrived, for: ChefGame.boilTime + 0.5)

        game.drop(.cooked(.bubbleTuber), at: .frontHousePortal)

        #expect(game.shift.ordersServed == 1)
        #expect(game.queue.orders.map(\.id) == [ids[1]])
        #expect(game.queue.active?.delivered == [1], "the new order's mushroom is handed off")
        #expect(kinds(game).compactMap { $0 }.allSatisfy(game.wantedIngredients.contains))
    }

    /// Multiplayer: a fully delivered order stays until Front House serves it.
    @Test func inMultiplayerADeliveredOrderStaysActive() throws {
        let game = makeGame([[.bubbleTuber, .bubbleTuber]], mode: .multiplayer)
        let activeID = game.queue.active?.id
        let round = ChefGame.boilTime + 0.5
        for index in 0..<2 {
            game.drop(try bubble(.bubbleTuber, in: game), at: .boilingPot)
            play(game, from: Double(index) * round, for: round)
            game.drop(.cooked(.bubbleTuber), at: .frontHousePortal)
        }

        #expect(game.queue.active?.isFullyDelivered == true)
        #expect(game.queue.active?.id == activeID)
        #expect(game.shift.ordersServed == 0)
    }

    @Test func anExpiredOrderCostsALife() {
        let game = makeGame([[.bubbleTuber, .starJelly]])
        play(game, for: OrderQueue.timeLimit + 1)
        #expect(game.shift.lives == KitchenShift.startingLives - 1)
    }

    // MARK: - Hands

    @Test func carriedItemsAreTrackedUntilUsedOrPutBack() throws {
        let game = makeGame([[.bubbleTuber, .coralLettuce]])
        let tuber = try bubble(.bubbleTuber, in: game)
        let coral = try bubble(.coralLettuce, in: game)

        game.pickUp(tuber)
        game.pickUp(coral)
        game.putBack(coral)
        #expect(game.itemsInHand == [tuber])

        game.drop(tuber, at: .boilingPot)
        #expect(game.itemsInHand.isEmpty)
    }
}
