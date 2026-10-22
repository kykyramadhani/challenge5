//
//  OrderQueueTests.swift
//  PlayFeatTests
//  Created by kyky on 22/10/26.
//
//  When orders arrive and when they run out, from the single-player rules:
//  the first at 0 s, then one every 20 s while there is room for three, each
//  with its own 60-second clock.
//

import CoreFoundation
import Testing
@testable import PlayFeat

struct OrderQueueTests {
    private func makeQueue() -> OrderQueue {
        OrderQueue(startingAt: 0) { KitchenOrder(id: $0, items: [.starJelly]) }
    }

    private func filledQueue() -> OrderQueue {
        var queue = makeQueue()
        queue.dealArrivals(at: 2 * OrderQueue.arrivalInterval)
        return queue
    }

    // MARK: - Arrivals

    @Test func theFirstOrderArrivesAtOnceThenOneEveryTwentySeconds() {
        var queue = makeQueue()
        #expect(queue.orders.map(\.arrivedAt) == [0])

        queue.dealArrivals(at: 19.9)
        #expect(queue.orders.count == 1)
        queue.dealArrivals(at: 40)
        #expect(queue.orders.map(\.arrivedAt) == [0, 20, 40])
    }

    @Test func aFullRailTakesNoMoreOrders() {
        var queue = filledQueue()
        queue.dealArrivals(at: 200)
        #expect(queue.orders.count == OrderQueue.capacity)
    }

    /// The rules' example: full at 40; a place opens at 50, so the next
    /// order is due at 70; another opening at 55 doesn't move it.
    @Test func theFirstPlaceToOpenStartsAFreshWaitAndLaterOnesKeepIt() {
        var queue = filledQueue()
        queue.remove(0, at: 50)
        queue.remove(1, at: 55)

        queue.dealArrivals(at: 69.9)
        #expect(queue.orders.count == 1)
        queue.dealArrivals(at: 70)
        #expect(queue.orders.map(\.arrivedAt) == [40, 70])
        queue.dealArrivals(at: 90)
        #expect(queue.orders.map(\.arrivedAt) == [40, 70, 90])
    }

    @Test func anEmptyRailWaitsForTheNextScheduledOrder() {
        var queue = makeQueue()
        queue.remove(0, at: 5)
        #expect(queue.orders.isEmpty)
        #expect(queue.active == nil)

        queue.dealArrivals(at: 19.9)
        #expect(queue.orders.isEmpty)
        queue.dealArrivals(at: 20)
        #expect(queue.orders.count == 1)
    }

    // MARK: - Working on any order

    /// A delivery counts for the most urgent order that still needs it.
    @Test func aDeliveryGoesToTheMostUrgentOrderThatNeedsIt() throws {
        var queue = OrderQueue(startingAt: 0) { id in
            KitchenOrder(id: id, items: id == 0 ? [.starJelly] : [.tentacle, .starJelly])
        }
        queue.dealArrivals(at: 20)
        #expect(queue.nextOpenRequirement(for: .tentacle) == OrderQueue.Requirement(orderID: 1, index: 0))

        let jelly = try #require(queue.nextOpenRequirement(for: .starJelly))
        #expect(jelly == OrderQueue.Requirement(orderID: 0, index: 0))
        queue.markDelivered(jelly)
        #expect(queue.nextOpenRequirement(for: .starJelly) == OrderQueue.Requirement(orderID: 1, index: 1))
    }

    // MARK: - Clocks

    @Test func eachOrderHasItsOwnClockFromItsArrival() {
        let queue = filledQueue()
        #expect(queue.fractionLeft(of: queue.orders[0], at: 30) == 0.5)
        #expect(queue.fractionLeft(of: queue.orders[1], at: 30) == CGFloat(50.0 / 60))
    }

    @Test func everyOrderPastItsTimeHasExpired() {
        var queue = filledQueue()
        #expect(queue.expiredOrders(at: 59.9).isEmpty)
        #expect(queue.expiredOrders(at: 80).map(\.arrivedAt) == [0, 20])

        queue.removeExpiredOrders(at: 80)
        #expect(queue.orders.map(\.arrivedAt) == [40])
    }

    @Test func aServedOrderNeverRunsOut() {
        var queue = makeQueue()
        queue.serve(0)
        #expect(queue.expiredOrders(at: 500).isEmpty)
        #expect(queue.isRunningLow(queue.orders[0], at: 55) == false)
    }
}
