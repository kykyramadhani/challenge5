//
//  KitchenCrew.swift
//  PlayFeat
//
//  Stand-in for the two roles the player isn't playing. The Chef cooks what
//  comes through the kitchen portal after a fixed time; Front House keeps
//  what arrives, serves an order on a clean tray once everything for it is
//  there, and the tray comes back to Procurement dirty.
//
//  ponytail: timed automation, not AI. Chef and Front House never make
//  mistakes or choices; replace with real role logic when those roles become
//  playable (or with the other iPads in co-op).
//

import Foundation

nonisolated struct KitchenCrew {
    static let cookTime: TimeInterval = 5
    static let trayReturnTime: TimeInterval = 6

    /// Raw ingredients on the Chef's stove, and when each one is done.
    private(set) var cooking: [(ingredient: KitchenIngredient, readyAt: TimeInterval)] = []
    /// Prepared ingredients waiting at Front House for their order.
    private(set) var pantry: [KitchenIngredient] = []
    /// Clean trays at Front House, ready to serve on.
    private(set) var cleanTrays: Int
    /// Dirty trays back at Procurement, waiting for the sink.
    private(set) var dirtyTrays: Int
    /// When each served tray lands back at Procurement.
    private var traysInTransit: [TimeInterval] = []

    init(cleanTrays: Int = 1, dirtyTrays: Int = 1) {
        self.cleanTrays = cleanTrays
        self.dirtyTrays = dirtyTrays
    }

    /// Everything already sent on its way: cooking, or waiting to be served.
    var sentIngredients: [KitchenIngredient] {
        pantry + cooking.map(\.ingredient)
    }

    // MARK: - Arrivals from Procurement

    /// An ingredient through a portal. Ones the Chef cooks or fries go to
    /// the stove first; the rest wait at Front House as they are.
    mutating func receive(_ ingredient: KitchenIngredient, at time: TimeInterval) {
        if ingredient.preparation.isChefWork {
            cooking.append((ingredient, time + Self.cookTime))
        } else {
            pantry.append(ingredient)
        }
    }

    mutating func receiveCleanTray() {
        cleanTrays += 1
    }

    /// Front House set a clean tray down to assemble an order on.
    mutating func takeCleanTray() {
        cleanTrays = max(0, cleanTrays - 1)
    }

    /// Front House sent a dirty tray back through the Procurement portal.
    mutating func receiveDirtyTray() {
        dirtyTrays += 1
    }

    /// Procurement put a dirty tray in the sink.
    mutating func takeDirtyTray() {
        dirtyTrays = max(0, dirtyTrays - 1)
    }

    // MARK: - Time passing

    /// Finishes cooking that is due and lands trays that have come back.
    mutating func update(at time: TimeInterval) {
        let done = cooking.filter { $0.readyAt <= time }
        cooking.removeAll { $0.readyAt <= time }
        pantry += done.map(\.ingredient)

        let landed = traysInTransit.filter { $0 <= time }.count
        traysInTransit.removeAll { $0 <= time }
        dirtyTrays += landed
    }

    /// `order` ran out of time: what was delivered for it — still cooking or
    /// waiting at Front House — is thrown away with it, so it can't quietly
    /// count toward another order.
    mutating func discardDeliveries(for order: KitchenOrder) {
        for index in order.items.indices where order.isDelivered(at: index) {
            remove(order.items[index])
        }
    }

    // MARK: - Serving

    func canServe(_ order: KitchenOrder) -> Bool {
        guard cleanTrays > 0 else { return false }
        var waiting = pantry
        for item in order.items {
            guard let index = waiting.firstIndex(of: item) else { return false }
            waiting.remove(at: index)
        }
        return true
    }

    /// Serves the order on a clean tray, which heads back dirty.
    mutating func serve(_ order: KitchenOrder, at time: TimeInterval) {
        guard canServe(order) else { return }
        takeAway(order, at: time)
    }

    /// Clears a finished order out without waiting to serve it (the
    /// playtest): what was sent for it leaves the kitchen, cooked or not, and
    /// a free clean tray still goes out and comes back dirty, so the sink
    /// keeps getting work.
    mutating func takeAway(_ order: KitchenOrder, at time: TimeInterval) {
        order.items.forEach { remove($0) }
        guard cleanTrays > 0 else { return }
        cleanTrays -= 1
        traysInTransit.append(time + Self.trayReturnTime)
    }

    private mutating func remove(_ ingredient: KitchenIngredient) {
        if let index = pantry.firstIndex(of: ingredient) {
            pantry.remove(at: index)
        } else if let index = cooking.firstIndex(where: { $0.ingredient == ingredient }) {
            cooking.remove(at: index)
        }
    }
}
