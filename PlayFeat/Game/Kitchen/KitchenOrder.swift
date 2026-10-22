//
//  KitchenOrder.swift
//  PlayFeat
//
//  One customer order: the dishes that make up its tray — one per tray
//  compartment — and maybe a drink; which of them have reached their
//  destination; and where the customer is with it (waiting, eating, done).
//

import Foundation

nonisolated struct KitchenOrder: Identifiable, Equatable {
    /// Where the customer is with the order. Only a waiting order is on the
    /// clock; once served it can't run out of time.
    enum Stage: Equatable {
        case waiting
        /// Served: the tray is on the green table and the customer is eating.
        case eating
        /// Finished eating: a dirty tray waits to go back to Procurement.
        case finishedEating
    }

    let id: Int
    let items: [KitchenIngredient]
    let needsDrink: Bool
    private(set) var stage = Stage.waiting
    /// Seconds of play when it reached the rail; its own clock runs from here.
    private(set) var arrivedAt: TimeInterval = 0
    /// Front House: the tray and the drink are served separately, in either
    /// order. Only with both is the order served (`serve()`).
    private(set) var isTrayServed = false
    private(set) var isDrinkServed = false
    /// Indices into `items` that have reached their destination: for
    /// Procurement, through the right portal; for the Chef, cooked and
    /// through the Front House portal.
    private(set) var delivered: Set<Int> = []

    init(id: Int, items: [KitchenIngredient], needsDrink: Bool = false) {
        self.id = id
        self.items = items
        self.needsDrink = needsDrink
    }

    /// A full tray has four dishes, a short one two — the two sizes the order
    /// tickets are drawn in. One dish per compartment, listed top-left,
    /// top-right, bottom-left, bottom-right, as on the tray.
    static func random(id: Int) -> KitchenOrder {
        let count = Bool.random() ? 4 : 2
        let compartments = TrayCompartment.allCases.shuffled().prefix(count)
        let items = TrayCompartment.allCases.filter(compartments.contains).compactMap { compartment in
            KitchenIngredient.allCases.filter { $0.trayCompartment == compartment }.randomElement()
        }
        return KitchenOrder(id: id, items: items, needsDrink: Bool.random())
    }

    /// A random order with at least one dish the Chef cooks, so a Chef shift
    /// never deals an order with nothing for the player to do.
    static func randomNeedingChef(id: Int) -> KitchenOrder {
        var order = random(id: id)
        while !order.items.contains(where: \.preparation.isChefWork) { order = random(id: id) }
        return order
    }

    /// Wants a drink that hasn't reached the customer yet.
    var isDrinkOwed: Bool { needsDrink && !isDrinkServed }

    /// Its tray is on the table and its drink, if any, has been poured.
    var isReadyToServe: Bool { isTrayServed && !isDrinkOwed }

    var isFullyDelivered: Bool { delivered.count == items.count }

    func isDelivered(at index: Int) -> Bool { delivered.contains(index) }

    /// The first requirement for `ingredient` not yet delivered — so two
    /// coral lettuces are ticked off one at a time, left to right.
    func nextOpenRequirement(for ingredient: KitchenIngredient) -> Int? {
        items.indices.first { items[$0] == ingredient && !delivered.contains($0) }
    }

    /// What is still to be delivered, one entry per open requirement.
    var openItems: [KitchenIngredient] {
        items.indices.filter { !delivered.contains($0) }.map { items[$0] }
    }

    mutating func markDelivered(at index: Int) {
        guard items.indices.contains(index) else { return }
        delivered.insert(index)
    }

    mutating func serve() {
        guard stage == .waiting else { return }
        stage = .eating
    }

    mutating func arrive(at time: TimeInterval) {
        arrivedAt = time
    }

    mutating func serveTray() {
        isTrayServed = true
    }

    mutating func serveDrink() {
        guard needsDrink else { return }
        isDrinkServed = true
    }

    mutating func finishEating() {
        guard stage == .eating else { return }
        stage = .finishedEating
    }
}
