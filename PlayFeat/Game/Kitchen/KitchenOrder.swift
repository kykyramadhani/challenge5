//
//  KitchenOrder.swift
//  PlayFeat
//
//  One customer order: the ingredients that have to reach the kitchen,
//  through the right portal, before it can be served — and which of them
//  already have. Duplicates are allowed: an order for two coral soups lists
//  coral lettuce twice, and each is delivered separately.
//

import Foundation

nonisolated struct KitchenOrder: Identifiable, Equatable {
    let id: Int
    let items: [KitchenIngredient]
    /// Indices into `items` that have reached their destination: for
    /// Procurement, through the right portal; for the Chef, cooked and
    /// through the Front House portal.
    private(set) var delivered: Set<Int> = []

    init(id: Int, items: [KitchenIngredient]) {
        self.id = id
        self.items = items
    }

    /// A full ticket has four items, a short one two — the two sizes the
    /// order tickets are drawn in.
    static func random(id: Int) -> KitchenOrder {
        let count = Bool.random() ? 4 : 2
        let items = (0..<count).compactMap { _ in KitchenIngredient.allCases.randomElement() }
        return KitchenOrder(id: id, items: items)
    }

    /// A random order with at least one dish the Chef cooks, so a Chef shift
    /// never deals an order with nothing for the player to do.
    static func randomNeedingChef(id: Int) -> KitchenOrder {
        var order = random(id: id)
        while !order.items.contains(where: \.preparation.isChefWork) { order = random(id: id) }
        return order
    }

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
}
