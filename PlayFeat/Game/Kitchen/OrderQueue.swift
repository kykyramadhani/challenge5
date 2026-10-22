//
//  OrderQueue.swift
//  PlayFeat
//
//  The orders on the rail — at most three — and when the next one arrives.
//  The first arrives as play starts, then one every 20 seconds while there
//  is room. Each order has its own 60-second clock from the moment it
//  arrives; finishing or losing another order never resets it. The player
//  works on any waiting order; one that fits several goes to the most urgent,
//  which is always the leftmost.
//

import Foundation

struct OrderQueue {
    /// One open item on one order: what a delivery ticks off.
    struct Requirement: Equatable {
        let orderID: KitchenOrder.ID
        let index: Int
    }

    /// Orders on the rail at once, served ones included until they leave.
    static let capacity = 3
    static let timeLimit: TimeInterval = 60
    static let arrivalInterval: TimeInterval = 20
    /// Below this many seconds a ticket starts blinking red.
    static let warningTime: TimeInterval = 10

    private(set) var orders: [KitchenOrder] = []
    /// When the next order arrives. Nil while the rail is full: nothing
    /// queues up out of sight.
    private var nextArrival: TimeInterval?
    private var nextID = 0
    private let makeOrder: (Int) -> KitchenOrder

    init(startingAt time: TimeInterval,
         makeOrder: @escaping (Int) -> KitchenOrder = KitchenOrder.random) {
        self.makeOrder = makeOrder
        nextArrival = time
        dealArrivals(at: time)
    }

    /// The orders still waiting, most urgent first: they arrive left to
    /// right with the same time each. Orders already served (Front House)
    /// keep their place on the rail, eating, until their tray is back.
    var waiting: [KitchenOrder] { orders.filter { $0.stage == .waiting } }
    /// The most urgent waiting order, nil while the rail waits for one.
    var active: KitchenOrder? { waiting.first }
    /// The waiting orders after the most urgent one.
    var upcoming: [KitchenOrder] { Array(waiting.dropFirst()) }

    /// Where a delivered `ingredient` counts: the next open item for it on
    /// the most urgent waiting order that still needs one.
    func nextOpenRequirement(for ingredient: KitchenIngredient) -> Requirement? {
        waiting.lazy.compactMap { order in
            order.nextOpenRequirement(for: ingredient).map { Requirement(orderID: order.id, index: $0) }
        }.first
    }

    // MARK: - Clocks

    /// How much of `order`'s time is left, 1 down to 0.
    func fractionLeft(of order: KitchenOrder, at time: TimeInterval) -> CGFloat {
        clock(of: order).fractionLeft(at: time)
    }

    /// Only a waiting order runs low or out of time; a served one is safe.
    func isRunningLow(_ order: KitchenOrder, at time: TimeInterval) -> Bool {
        guard order.stage == .waiting else { return false }
        let left = fractionLeft(of: order, at: time) * Self.timeLimit
        return left > 0 && left < Self.warningTime
    }

    func expiredOrders(at time: TimeInterval) -> [KitchenOrder] {
        orders.filter { $0.stage == .waiting && clock(of: $0).hasRunOut(at: time) }
    }

    private func clock(of order: KitchenOrder) -> Countdown {
        Countdown(duration: Self.timeLimit, startingAt: order.arrivedAt)
    }

    // MARK: - Arrivals

    /// Deals every order due by `time`, while there is room.
    mutating func dealArrivals(at time: TimeInterval) {
        while let arrival = nextArrival, arrival <= time, orders.count < Self.capacity {
            var order = makeOrder(nextID)
            nextID += 1
            order.arrive(at: arrival)
            orders.append(order)
            nextArrival = orders.count < Self.capacity ? arrival + Self.arrivalInterval : nil
        }
    }

    // MARK: - Working on an order

    mutating func markDelivered(_ requirement: Requirement) {
        update(requirement.orderID) { $0.markDelivered(at: requirement.index) }
    }

    mutating func serveTray(of orderID: KitchenOrder.ID) {
        update(orderID) { $0.serveTray() }
    }

    mutating func serveDrink(of orderID: KitchenOrder.ID) {
        update(orderID) { $0.serveDrink() }
    }

    /// The order is served and keeps its place, eating. It leaves once its
    /// tray is back (`clearFinishedOrder`).
    mutating func serve(_ orderID: KitchenOrder.ID) {
        update(orderID) { $0.serve() }
    }

    mutating func finishEating(orderID: KitchenOrder.ID) {
        update(orderID) { $0.finishEating() }
    }

    private mutating func update(_ orderID: KitchenOrder.ID, _ change: (inout KitchenOrder) -> Void) {
        guard let index = orders.firstIndex(where: { $0.id == orderID }) else { return }
        change(&orders[index])
    }

    // MARK: - Leaving the rail

    /// The order is done and leaves the rail.
    mutating func remove(_ orderID: KitchenOrder.ID, at time: TimeInterval) {
        guard let index = orders.firstIndex(where: { $0.id == orderID }) else { return }
        remove(at: index, time: time)
    }

    /// The oldest finished order's tray is back: it leaves the rail.
    mutating func clearFinishedOrder(at time: TimeInterval) {
        guard let index = orders.firstIndex(where: { $0.stage == .finishedEating }) else { return }
        remove(at: index, time: time)
    }

    mutating func removeExpiredOrders(at time: TimeInterval) {
        let expired = Set(expiredOrders(at: time).map(\.id))
        while let index = orders.firstIndex(where: { expired.contains($0.id) }) {
            remove(at: index, time: time)
        }
    }

    /// The rest slide left. The first place to open on a full rail starts a
    /// fresh wait for the next order; more places opening don't shorten it.
    private mutating func remove(at index: Int, time: TimeInterval) {
        orders.remove(at: index)
        if nextArrival == nil { nextArrival = time + Self.arrivalInterval }
    }
}
