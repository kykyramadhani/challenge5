//
//  ProcurementGameTests.swift
//  PlayFeatTests
//
//  A Procurement shift without a camera: the order rail and its clock, card
//  replacement, chopping, washing and the tray loop through the stand-in crew.
//

import CoreFoundation
import Testing
@testable import PlayFeat

@MainActor
struct ProcurementGameTests {
    /// A playtest shift where every order is one star jelly unless a test says
    /// otherwise, so finishing an order takes a single drop through the Front
    /// House portal.
    private func makeGame(order: [KitchenIngredient] = [.starJelly],
                          crew: KitchenCrew = KitchenCrew(cleanTrays: 1, dirtyTrays: 1),
                          mode: KitchenMode = .playtest) -> ProcurementGame {
        ProcurementGame(mode: mode, wallTime: 0, crew: crew) { KitchenOrder(id: $0, items: order) }
    }

    /// Runs the shift clock forward in steps the play clock credits in full.
    private func play(_ game: ProcurementGame, until seconds: Double) {
        var wall = 0.0
        while wall < seconds {
            wall += 0.2
            game.tick(wallTime: wall)
        }
    }

    private func slot(of ingredient: KitchenIngredient, in game: ProcurementGame) throws -> Int {
        try #require(game.cards.firstIndex(of: ingredient))
    }

    // MARK: - Orders

    @Test func activeOrderExpiresAfterSixtySecondsAndCostsALife() {
        let game = makeGame(order: [.coralLettuce])
        let firstID = game.queue.active.id

        play(game, until: 51)
        #expect(game.isActiveOrderRunningLow)
        #expect(game.lives == 3)

        play(game, until: 61)
        #expect(game.lives == 2)
        #expect(game.queue.active.id == firstID + 1)
        #expect(game.queue.orders.count == OrderQueue.size)
        #expect(!game.isActiveOrderRunningLow)
    }

    @Test func servingShiftsTheRailAndDealsANewOrderAtTheEnd() throws {
        let game = makeGame()
        let ids = game.queue.orders.map(\.id)

        game.drop(.ingredient(.starJelly, cardSlot: try slot(of: .starJelly, in: game)), at: .frontHousePortal)

        #expect(game.ordersServed == 1)
        #expect(game.queue.orders.map(\.id) == Array(ids.dropFirst()) + [ids.last! + 1])
    }

    @Test func losingTheLastLifeEndsTheShift() {
        let game = makeGame(order: [.coralLettuce])
        play(game, until: 181)
        #expect(game.lives == 0)
        #expect(game.isOver)
    }

    // MARK: - Cards

    @Test(arguments: 0..<IngredientCardPicker.cardCount)
    func onlyTheUsedCardIsReplaced(used: Int) {
        let game = makeGame(order: [.glowingMushroom, .coralLettuce, .bubbleTuber, .starJelly])
        let before = game.cards

        game.drop(.ingredient(before[used], cardSlot: used), at: .trash)

        for index in before.indices where index != used {
            #expect(game.cards[index] == before[index])
        }
    }

    @Test func aRejectedDropKeepsTheCard() throws {
        let game = makeGame(order: [.coralLettuce, .bubbleTuber])
        let before = game.cards
        let item = CarriedItem.ingredient(before[0], cardSlot: 0)

        #expect(!game.accepts(item, at: .sink))
        game.drop(item, at: .sink)

        #expect(game.cards == before)
    }

    // MARK: - Cutting

    @Test func threeChopsSliceTheIngredientAndCloseTheBoard() throws {
        let game = makeGame(order: [.glowingMushroom])
        game.drop(.ingredient(.glowingMushroom, cardSlot: try slot(of: .glowingMushroom, in: game)), at: .cuttingBoard)
        #expect(game.station == .cutting(.glowingMushroom))

        game.registerChop()
        game.registerChop()
        #expect(game.slicedOnBoard == nil)
        game.registerChop()
        #expect(game.slicedOnBoard == .glowingMushroom)

        play(game, until: 1)
        #expect(game.station == .worktop)

        game.drop(.sliced(.glowingMushroom), at: .frontHousePortal)
        #expect(game.slicedOnBoard == nil)
        #expect(game.ordersServed == 1)
    }

    @Test func inMultiplayerCookedIngredientsAreServedAfterTheChef() throws {
        let game = makeGame(order: [.coralLettuce], mode: .multiplayer)
        game.drop(.ingredient(.coralLettuce, cardSlot: try slot(of: .coralLettuce, in: game)), at: .kitchenPortal)
        #expect(game.ordersServed == 0)

        play(game, until: KitchenCrew.cookTime + 0.5)
        #expect(game.ordersServed == 1)
    }

    // MARK: - Delivery

    /// Lettuce (soup), tuber (boiled) and tentacle (fried) go to the Chef raw.
    /// Front House refuses them; through the Chef portal exactly one of the
    /// two matching requirements is ticked off at once, before any cooking.
    @Test(arguments: [KitchenIngredient.coralLettuce, .bubbleTuber, .tentacle])
    func rawIngredientsForTheChefAreMarkedDoneImmediately(ingredient: KitchenIngredient) throws {
        let game = makeGame(order: [ingredient, .starJelly, ingredient])
        let item = CarriedItem.ingredient(ingredient, cardSlot: try slot(of: ingredient, in: game))

        #expect(!game.accepts(item, at: .frontHousePortal))
        game.drop(item, at: .kitchenPortal)

        #expect(game.queue.active.delivered == [0])
        #expect(game.ordersServed == 0)
        #expect(game.crew.sentIngredients == [ingredient])
    }

    /// Star jelly is a dessert, ready as it is: Front House takes it directly.
    @Test func starJellyThroughFrontHouseIsMarkedDoneImmediately() throws {
        let game = makeGame(order: [.coralLettuce, .starJelly])

        game.drop(.ingredient(.starJelly, cardSlot: try slot(of: .starJelly, in: game)), at: .frontHousePortal)

        #expect(game.queue.active.isDelivered(at: 1))
        #expect(!game.queue.active.isDelivered(at: 0))
    }

    @Test func slicedMushroomThroughFrontHouseIsMarkedDone() throws {
        let game = makeGame(order: [.glowingMushroom, .coralLettuce])
        game.drop(.ingredient(.glowingMushroom, cardSlot: try slot(of: .glowingMushroom, in: game)), at: .cuttingBoard)
        (0..<ProcurementGame.chopsNeeded).forEach { _ in game.registerChop() }
        play(game, until: 1)

        #expect(!game.accepts(.sliced(.glowingMushroom), at: .kitchenPortal))
        game.drop(.sliced(.glowingMushroom), at: .frontHousePortal)

        #expect(game.queue.active.delivered == [0])
        #expect(game.slicedOnBoard == nil)
    }

    /// Every wrong route is refused: nothing ticked, nothing sent, no card
    /// used up — the item just floats back.
    @Test func wrongDestinationsAreRefused() throws {
        let game = makeGame(order: [.coralLettuce, .starJelly, .glowingMushroom])
        let cards = game.cards
        let refused: [(CarriedItem, DropZone)] = [
            (.ingredient(.coralLettuce, cardSlot: try slot(of: .coralLettuce, in: game)), .frontHousePortal),
            (.ingredient(.starJelly, cardSlot: try slot(of: .starJelly, in: game)), .kitchenPortal),
            (.ingredient(.glowingMushroom, cardSlot: try slot(of: .glowingMushroom, in: game)), .kitchenPortal),
            (.ingredient(.glowingMushroom, cardSlot: try slot(of: .glowingMushroom, in: game)), .frontHousePortal),
        ]

        for (item, portal) in refused {
            #expect(!game.accepts(item, at: portal), "\(item) through \(portal)")
            game.drop(item, at: portal)
        }

        #expect(game.queue.active.delivered.isEmpty)
        #expect(game.crew.sentIngredients.isEmpty)
        #expect(game.cards == cards)
    }

    /// An ingredient the active order doesn't (or no longer) need doesn't
    /// count, even through the right portal.
    @Test func anIngredientTheActiveOrderDoesNotNeedIsRefused() throws {
        let game = makeGame(order: [.starJelly, .coralLettuce])
        game.drop(.ingredient(.starJelly, cardSlot: try slot(of: .starJelly, in: game)), at: .frontHousePortal)

        let again = CarriedItem.ingredient(.starJelly, cardSlot: try slot(of: .starJelly, in: game))
        #expect(!game.accepts(again, at: .frontHousePortal))
        game.drop(again, at: .frontHousePortal)

        #expect(game.queue.active.delivered == [0])
        #expect(game.crew.sentIngredients == [.starJelly])
    }

    /// Two of the same on a ticket fill one at a time, left to right; a third
    /// has nothing left to fill.
    @Test func repeatedIngredientsFillTheNextOpenRequirement() throws {
        let game = makeGame(order: [.coralLettuce, .coralLettuce, .starJelly])

        game.drop(.ingredient(.coralLettuce, cardSlot: try slot(of: .coralLettuce, in: game)), at: .kitchenPortal)
        #expect(game.queue.active.delivered == [0])

        game.drop(.ingredient(.coralLettuce, cardSlot: try slot(of: .coralLettuce, in: game)), at: .kitchenPortal)
        #expect(game.queue.active.delivered == [0, 1])

        #expect(game.delivery(of: .coralLettuce, sliced: false, to: .kitchenPortal) == nil)
    }

    /// The same sliced mushroom can't be delivered twice.
    @Test func aDeliveryCountsExactlyOnce() throws {
        let game = makeGame(order: [.glowingMushroom, .glowingMushroom])
        game.drop(.ingredient(.glowingMushroom, cardSlot: try slot(of: .glowingMushroom, in: game)), at: .cuttingBoard)
        (0..<ProcurementGame.chopsNeeded).forEach { _ in game.registerChop() }
        play(game, until: 1)

        game.drop(.sliced(.glowingMushroom), at: .frontHousePortal)
        game.drop(.sliced(.glowingMushroom), at: .frontHousePortal)

        #expect(game.queue.active.delivered == [0])
    }

    /// When an order runs out of time, what was delivered for it goes with it
    /// and doesn't tick off anything on the next order.
    @Test func anExpiredOrdersDeliveriesAreDiscarded() throws {
        let game = makeGame(order: [.coralLettuce, .starJelly])
        game.drop(.ingredient(.coralLettuce, cardSlot: try slot(of: .coralLettuce, in: game)), at: .kitchenPortal)

        play(game, until: OrderQueue.timeLimit + 1)

        #expect(game.crew.sentIngredients.isEmpty)
        #expect(game.queue.active.delivered.isEmpty)
    }

    // MARK: - Completing an order

    /// Playtest: the last correct delivery finishes the order on the spot —
    /// no clean tray, and the Chef hasn't cooked the lettuce yet. The rail
    /// shifts left and a new order is dealt at the end.
    @Test func inThePlaytestDeliveringEverythingCompletesTheOrderAtOnce() throws {
        let game = makeGame(order: [.coralLettuce, .glowingMushroom, .starJelly],
                            crew: KitchenCrew(cleanTrays: 0, dirtyTrays: 0))
        let ids = game.queue.orders.map(\.id)

        game.drop(.ingredient(.coralLettuce, cardSlot: try slot(of: .coralLettuce, in: game)), at: .kitchenPortal)
        game.drop(.ingredient(.glowingMushroom, cardSlot: try slot(of: .glowingMushroom, in: game)), at: .cuttingBoard)
        (0..<ProcurementGame.chopsNeeded).forEach { _ in game.registerChop() }
        play(game, until: 1)
        game.drop(.sliced(.glowingMushroom), at: .frontHousePortal)
        #expect(game.ordersServed == 0)

        game.drop(.ingredient(.starJelly, cardSlot: try slot(of: .starJelly, in: game)), at: .frontHousePortal)

        #expect(game.ordersServed == 1)
        #expect(game.queue.orders.map(\.id) == Array(ids.dropFirst()) + [ids.last! + 1])
        #expect(game.queue.active.delivered.isEmpty)
        #expect(game.queue.fractionLeft(at: game.now) == 1)
        #expect(game.crew.sentIngredients.isEmpty)
        #expect(game.lives == ProcurementGame.startingLives)
    }

    /// Playtest: a finished order still goes out on a free clean tray, so a
    /// dirty one comes back for the sink.
    @Test func inThePlaytestACompletedOrderStillUsesAFreeTray() throws {
        let game = makeGame(crew: KitchenCrew(cleanTrays: 1, dirtyTrays: 0))
        game.drop(.ingredient(.starJelly, cardSlot: try slot(of: .starJelly, in: game)), at: .frontHousePortal)

        play(game, until: KitchenCrew.trayReturnTime + 0.5)
        #expect(game.crew.cleanTrays == 0)
        #expect(game.crew.dirtyTrays == 1)
    }

    /// Multiplayer: a fully delivered order stays on the rail, ticked off,
    /// until Front House serves it — here once the Chef has cooked.
    @Test func inMultiplayerAFullyDeliveredOrderWaitsToBeServed() throws {
        let game = makeGame(order: [.coralLettuce, .starJelly], mode: .multiplayer)
        let firstID = game.queue.active.id

        game.drop(.ingredient(.coralLettuce, cardSlot: try slot(of: .coralLettuce, in: game)), at: .kitchenPortal)
        game.drop(.ingredient(.starJelly, cardSlot: try slot(of: .starJelly, in: game)), at: .frontHousePortal)
        #expect(game.queue.active.id == firstID)
        #expect(game.queue.active.isFullyDelivered)
        #expect(game.ordersServed == 0)

        play(game, until: KitchenCrew.cookTime + 0.5)
        #expect(game.ordersServed == 1)
        #expect(game.queue.active.id == firstID + 1)
    }

    /// Multiplayer: delivered but never served still runs out of time.
    @Test func inMultiplayerAnUnservedOrderStillExpires() throws {
        let game = makeGame(crew: KitchenCrew(cleanTrays: 0, dirtyTrays: 0), mode: .multiplayer)
        game.drop(.ingredient(.starJelly, cardSlot: try slot(of: .starJelly, in: game)), at: .frontHousePortal)

        play(game, until: OrderQueue.timeLimit + 1)
        #expect(game.ordersServed == 0)
        #expect(game.lives == ProcurementGame.startingLives - 1)
    }

    // MARK: - Cards stay distinct

    /// However many times cards are used and re-dealt, the three on screen
    /// are three different ingredients, and only the used one changes.
    @Test(arguments: [[KitchenIngredient.coralLettuce, .coralLettuce, .coralLettuce, .coralLettuce],
                      [.glowingMushroom, .coralLettuce, .bubbleTuber, .starJelly],
                      [.starJelly, .starJelly]])
    func cardsAreAlwaysThreeDifferentIngredients(order: [KitchenIngredient]) {
        let game = makeGame(order: order)
        #expect(Set(game.cards).count == IngredientCardPicker.cardCount)

        for round in 0..<60 {
            let used = round % IngredientCardPicker.cardCount
            let before = game.cards
            game.drop(.ingredient(before[used], cardSlot: used), at: .trash)

            #expect(Set(game.cards).count == IngredientCardPicker.cardCount, "duplicate after round \(round)")
            for index in before.indices where index != used {
                #expect(game.cards[index] == before[index])
            }
        }
    }

    // MARK: - Trays

    @Test func washingTurnsADirtyTrayIntoACleanOneForFrontHouse() {
        let game = makeGame(crew: KitchenCrew(cleanTrays: 0, dirtyTrays: 1))
        game.drop(.dirtyTray, at: .sink)
        #expect(game.station == .washing)
        #expect(game.crew.dirtyTrays == 0)

        game.addScrub(circles: 1.5)
        #expect(game.cleanTraysReady == 0)
        game.addScrub(circles: 1.5)
        #expect(game.cleanTraysReady == 1)

        play(game, until: 1)
        game.drop(.cleanTray, at: .frontHousePortal)
        #expect(game.crew.cleanTrays == 1)
        // The same tray can't go through twice.
        #expect(!game.accepts(.cleanTray, at: .frontHousePortal))
    }

    @Test func inMultiplayerNoCleanTrayMeansNoServe() throws {
        let game = makeGame(crew: KitchenCrew(cleanTrays: 0, dirtyTrays: 0), mode: .multiplayer)
        game.drop(.ingredient(.starJelly, cardSlot: try slot(of: .starJelly, in: game)), at: .frontHousePortal)
        #expect(game.ordersServed == 0)
    }

    @Test func aServedTrayComesBackDirty() throws {
        let game = makeGame(crew: KitchenCrew(cleanTrays: 1, dirtyTrays: 0))
        game.drop(.ingredient(.starJelly, cardSlot: try slot(of: .starJelly, in: game)), at: .frontHousePortal)
        #expect(game.crew.dirtyTrays == 0)

        play(game, until: KitchenCrew.trayReturnTime + 0.5)
        #expect(game.crew.dirtyTrays == 1)
    }
}
