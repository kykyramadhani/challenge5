//
//  KitchenShift.swift
//  PlayFeat
//
//  What every role's shift has in common: the order rail and its clocks,
//  lives, the served count and the end of the shift. ProcurementGame and
//  ChefGame each own one and add their own stations on top, so the rules for
//  timing, losing and completing orders live in one place.
//

import Foundation
import QuartzCore

@Observable
final class KitchenShift {
    static let startingLives = 3

    let mode: KitchenMode
    private(set) var queue: OrderQueue
    private(set) var lives = startingLives
    private(set) var ordersServed = 0
    private(set) var isOver = false
    /// Whole seconds of play, for the shift clock.
    private(set) var elapsedSeconds = 0
    /// Orders with under ten seconds left. Changes rarely, so it is safe to
    /// observe; each ticket's border is drawn from `fractionLeft(of:)`.
    private(set) var runningLowOrderIDs: Set<KitchenOrder.ID> = []

    /// The role's game step, run on every timer tick once the shift starts.
    @ObservationIgnored var onTick: ((TimeInterval) -> Void)?
    @ObservationIgnored private var clock: PlayClock
    @ObservationIgnored private var timer: Timer?

    private static let tickInterval: TimeInterval = 1.0 / 30

    init(mode: KitchenMode, wallTime: TimeInterval, makeOrder: @escaping (Int) -> KitchenOrder) {
        self.mode = mode
        clock = PlayClock(wallTime: wallTime)
        queue = OrderQueue(startingAt: 0, makeOrder: makeOrder)
    }

    deinit { timer?.invalidate() }

    /// Seconds of play — the clock every order deadline is measured on.
    var now: TimeInterval { clock.elapsed }

    func fractionLeft(of order: KitchenOrder) -> CGFloat { queue.fractionLeft(of: order, at: now) }

    var isAnyOrderRunningLow: Bool { !runningLowOrderIDs.isEmpty }

    /// Waiting orders whose time has run out, not yet failed.
    var expiredOrders: [KitchenOrder] { queue.expiredOrders(at: now) }

    // MARK: - Lifecycle

    /// Starts the clock. Nothing before this — the countdown, the camera
    /// warming up — is credited to any order.
    func start() {
        guard timer == nil, !isOver else { return }
        clock.hold(at: CACurrentMediaTime())
        timer = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            self?.onTick?(CACurrentMediaTime())
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Moves play time on to `wallTime` and deals the orders due by then.
    /// Internal so tests can drive it.
    func advanceClock(to wallTime: TimeInterval) {
        clock.advance(to: wallTime)
        queue.dealArrivals(at: now)
        let seconds = Int(now)
        if seconds != elapsedSeconds { elapsedSeconds = seconds }
        updateRunningLow()
    }

    private func updateRunningLow() {
        let runningLow = Set(queue.orders.filter { queue.isRunningLow($0, at: now) }.map(\.id))
        if runningLow != runningLowOrderIDs { runningLowOrderIDs = runningLow }
    }

    // MARK: - Orders

    func markDelivered(_ requirement: OrderQueue.Requirement) {
        queue.markDelivered(requirement)
    }

    /// An order's tray or drink reaches the customer; the order itself is
    /// served once both have (`serveOrder`).
    func serveTray(of orderID: KitchenOrder.ID) {
        queue.serveTray(of: orderID)
    }

    func serveDrink(of orderID: KitchenOrder.ID) {
        queue.serveDrink(of: orderID)
    }

    /// The customer has their tray and starts eating, off the clock.
    func serveOrder(_ orderID: KitchenOrder.ID) {
        queue.serve(orderID)
        updateRunningLow()
    }

    func finishEating(orderID: KitchenOrder.ID) {
        queue.finishEating(orderID: orderID)
    }

    /// A served order's dirty tray is back: it counts as served and leaves
    /// the rail.
    func completeServedOrder() {
        ordersServed += 1
        queue.clearFinishedOrder(at: now)
    }

    /// The waiting orders that are done and can leave the rail. Every
    /// requirement has to be delivered either way; with all three roles it
    /// also has to have been served, which only Front House knows
    /// (`isServed`).
    func finishedOrders(isServed: (KitchenOrder) -> Bool) -> [KitchenOrder] {
        queue.waiting.filter { order in
            guard order.isFullyDelivered else { return false }
            switch mode {
            case .playtest: return true
            case .multiplayer: return isServed(order)
            }
        }
    }

    /// The order is done: it counts as served and leaves the rail.
    func complete(_ orderID: KitchenOrder.ID) {
        ordersServed += 1
        queue.remove(orderID, at: now)
        updateRunningLow()
    }

    /// Every order that ran out of time leaves the rail and costs a life.
    /// The last life ends the shift at once.
    func failExpiredOrders() {
        let expired = expiredOrders.count
        guard expired > 0 else { return }
        lives = max(0, lives - expired)
        queue.removeExpiredOrders(at: now)
        updateRunningLow()
        if lives == 0 { end() }
    }

    /// Ends the shift: the last life lost, or the player pressing Stop.
    func end() {
        isOver = true
        stop()
    }
}
