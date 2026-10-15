//
//  OrderQueue.swift
//  PlayFeat
//
//  The four orders on the rail. The leftmost is the active one: only it is
//  being timed, and it is the one Front House serves next. Finishing or
//  losing it slides the rest forward and deals a new order onto the end.
//

import Foundation

struct OrderQueue {
    static let size = 4
    static let timeLimit: TimeInterval = 60
    /// Below this many seconds the active ticket starts blinking red.
    static let warningTime: TimeInterval = 10

    private(set) var orders: [KitchenOrder]
    private var countdown: Countdown
    private var nextID: Int
    private let makeOrder: (Int) -> KitchenOrder

    init(startingAt time: TimeInterval,
         makeOrder: @escaping (Int) -> KitchenOrder = KitchenOrder.random) {
        self.makeOrder = makeOrder
        orders = (0..<Self.size).map(makeOrder)
        nextID = Self.size
        countdown = Countdown(duration: Self.timeLimit, startingAt: time)
    }

    /// Where the active order is: the leftmost one still waiting. Orders
    /// already served (Front House) keep their place, eating, until their
    /// tray is back; for the other roles it's always the first.
    var activeIndex: Int { orders.firstIndex { $0.stage == .waiting } ?? 0 }
    var active: KitchenOrder { orders[activeIndex] }
    var upcoming: ArraySlice<KitchenOrder> { orders[(activeIndex + 1)...] }

    /// How much of the active order's time is left, 1 down to 0.
    func fractionLeft(at time: TimeInterval) -> CGFloat {
        countdown.fractionLeft(at: time)
    }

    func isRunningLow(at time: TimeInterval) -> Bool {
        guard active.stage == .waiting else { return false }
        let left = countdown.fractionLeft(at: time) * Self.timeLimit
        return left > 0 && left < Self.warningTime
    }

    /// Only a waiting order runs out of time; a served one is safe.
    func hasExpired(at time: TimeInterval) -> Bool {
        active.stage == .waiting && countdown.hasRunOut(at: time)
    }

    /// Ticks off one of the active order's requirements.
    mutating func markActiveRequirementDelivered(at index: Int) {
        orders[activeIndex].markDelivered(at: index)
    }

    /// The active order is served and keeps its place, eating. The next
    /// waiting order becomes active with a fresh clock; nothing new is dealt
    /// until the served one leaves (`clearFinishedOrder`).
    mutating func serveActive(at time: TimeInterval) {
        orders[activeIndex].serve()
        countdown = Countdown(duration: Self.timeLimit, startingAt: time)
    }

    mutating func finishEating(orderID: KitchenOrder.ID) {
        guard let index = orders.firstIndex(where: { $0.id == orderID }) else { return }
        orders[index].finishEating()
    }

    /// The oldest finished order's tray is back: it leaves, the rest slide
    /// left and a new order is dealt at the end. The active order keeps its
    /// clock.
    mutating func clearFinishedOrder() {
        guard let index = orders.firstIndex(where: { $0.stage == .finishedEating }) else { return }
        orders.remove(at: index)
        dealNewOrder()
    }

    /// The active order is done with — completed or expired. The next one
    /// becomes active with a fresh clock.
    mutating func advance(at time: TimeInterval) {
        orders.remove(at: activeIndex)
        dealNewOrder()
        countdown = Countdown(duration: Self.timeLimit, startingAt: time)
    }

    private mutating func dealNewOrder() {
        orders.append(makeOrder(nextID))
        nextID += 1
    }
}
