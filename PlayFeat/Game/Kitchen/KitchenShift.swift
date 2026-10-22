//
//  KitchenShift.swift
//  PlayFeat
//
//  What every role's shift has in common: the order rail and its clock,
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
    /// The active ticket has under ten seconds left. Flips rarely, so it is
    /// safe to observe; the border itself is drawn from `activeFractionLeft`.
    private(set) var isActiveOrderRunningLow = false

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

    var activeFractionLeft: CGFloat { queue.fractionLeft(at: now) }

    var hasActiveOrderExpired: Bool { queue.hasExpired(at: now) }

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

    /// Moves play time on to `wallTime`. Internal so tests can drive it.
    func advanceClock(to wallTime: TimeInterval) {
        clock.advance(to: wallTime)
        let seconds = Int(now)
        if seconds != elapsedSeconds { elapsedSeconds = seconds }
        updateRunningLow()
    }

    private func updateRunningLow() {
        let runningLow = queue.isRunningLow(at: now)
        if runningLow != isActiveOrderRunningLow { isActiveOrderRunningLow = runningLow }
    }

    // MARK: - Orders

    func markActiveRequirementDelivered(at index: Int) {
        queue.markActiveRequirementDelivered(at: index)
    }

    /// The customer has their tray and starts eating, off the clock; the
    /// next order becomes active straight away.
    func serveActiveOrder() {
        queue.serveActive(at: now)
        updateRunningLow()
    }

    /// Gives the active order its full time again.
    func restartActiveClock() {
        queue.restartClock(at: now)
        updateRunningLow()
    }

    func finishEating(orderID: KitchenOrder.ID) {
        queue.finishEating(orderID: orderID)
    }

    /// The active order's tray or drink reaches the customer; the order
    /// itself is served once both have (`serveActiveOrder`).
    func serveActiveTray() {
        queue.serveActiveTray()
    }

    func serveActiveDrink() {
        queue.serveActiveDrink()
    }

    /// A served order's dirty tray is back: it counts as served, leaves the
    /// rail, and a new order is dealt at the end.
    func completeServedOrder() {
        ordersServed += 1
        queue.clearFinishedOrder()
    }

    /// Whether the active order is done and can leave the rail. Every
    /// requirement has to be delivered either way; with all three roles it
    /// also has to have been served, which only Front House knows
    /// (`isServed`).
    func isActiveOrderFinished(isServed: @autoclosure () -> Bool) -> Bool {
        guard queue.active.isFullyDelivered else { return false }
        switch mode {
        case .playtest: return true
        case .multiplayer: return isServed()
        }
    }

    /// The active order is done: it counts as served and the rail moves up.
    func completeActiveOrder() {
        ordersServed += 1
        queue.advance(at: now)
        updateRunningLow()
    }

    /// The active order ran out of time: it costs a life and the rail moves
    /// up. The last life ends the shift.
    func failActiveOrder() {
        lives -= 1
        queue.advance(at: now)
        updateRunningLow()
        if lives <= 0 { end() }
    }

    /// Ends the shift: the last life lost, or the player pressing Stop.
    func end() {
        isOver = true
        stop()
    }
}
