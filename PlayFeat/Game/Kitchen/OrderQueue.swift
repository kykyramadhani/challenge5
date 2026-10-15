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

    var active: KitchenOrder { orders[0] }
    var upcoming: ArraySlice<KitchenOrder> { orders.dropFirst() }

    /// How much of the active order's time is left, 1 down to 0.
    func fractionLeft(at time: TimeInterval) -> CGFloat {
        countdown.fractionLeft(at: time)
    }

    func isRunningLow(at time: TimeInterval) -> Bool {
        let left = countdown.fractionLeft(at: time) * Self.timeLimit
        return left > 0 && left < Self.warningTime
    }

    func hasExpired(at time: TimeInterval) -> Bool {
        countdown.hasRunOut(at: time)
    }

    /// Ticks off one of the active order's requirements.
    mutating func markActiveRequirementDelivered(at index: Int) {
        orders[0].markDelivered(at: index)
    }

    /// The active order is done with — served or expired. The next one
    /// becomes active with a fresh clock.
    mutating func advance(at time: TimeInterval) {
        orders.removeFirst()
        orders.append(makeOrder(nextID))
        nextID += 1
        countdown = Countdown(duration: Self.timeLimit, startingAt: time)
    }
}
