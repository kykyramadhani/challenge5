//
//  BubbleRack.swift
//  PlayFeat
//
//  The five floating bubbles of the Chef and Front House, and what keeps
//  them filled: `BubblePicker` decides what each slot should hold, this
//  gives every new arrival a fresh identity so it animates in.
//

import Foundation

/// One ingredient or dish floating in a bubble. The id is fresh for every
/// arrival, so a replacement animates in even when it's the same kind.
nonisolated struct FloatingBubble: Equatable, Identifiable {
    let id: Int
    let ingredient: KitchenIngredient
}

nonisolated struct BubbleRack {
    private(set) var slots: [FloatingBubble?] = Array(repeating: nil, count: BubblePicker.slotCount)
    private var nextID = 0

    /// Clears bubbles nobody needs any more and sends new ones in for empty
    /// slots. Bubbles still wanted keep their slot and their identity.
    mutating func refill(wanted: [KitchenIngredient]) {
        let refilled = BubblePicker.refill(slots.map { $0?.ingredient }, wanted: wanted)
        for slot in slots.indices where slots[slot]?.ingredient != refilled[slot] {
            slots[slot] = refilled[slot].map { ingredient in
                defer { nextID += 1 }
                return FloatingBubble(id: nextID, ingredient: ingredient)
            }
        }
    }

    /// The bubble in `slot` was used up.
    mutating func empty(_ slot: Int) {
        slots[slot] = nil
    }

    func holds(_ ingredient: KitchenIngredient, in slot: Int) -> Bool {
        slots.indices.contains(slot) && slots[slot]?.ingredient == ingredient
    }
}
