//
//  BubblePicker.swift
//  PlayFeat
//
//  Decides what floats in the five bubbles of the Chef (raw ingredients from
//  Procurement) and Front House (finished dishes from the Chef). Each bubble
//  stands for one requirement, so a bubble only ever stands for something an
//  order still needs and nothing is supplied twice. The active order comes
//  first (up to four bubbles), then the orders behind it, so the fifth looks
//  ahead. Bubbles still wanted stay exactly where they are; only empty slots
//  are filled.
//

import Foundation

enum BubblePicker {
    static let slotCount = 5

    /// The bubbles after a change: each one still wanted keeps its slot, one
    /// nothing wants any more is cleared, and empty slots are filled in
    /// order from what is left of `wanted`.
    ///
    /// - Parameters:
    ///   - slots: what is floating now, one entry per slot.
    ///   - wanted: every raw ingredient the Chef still needs, most urgent
    ///     first — the active order's, then the next orders'.
    static func refill(_ slots: [KitchenIngredient?], wanted: [KitchenIngredient]) -> [KitchenIngredient?] {
        var unclaimed = wanted
        var refilled = slots.map { bubble -> KitchenIngredient? in
            guard let bubble, let index = unclaimed.firstIndex(of: bubble) else { return nil }
            unclaimed.remove(at: index)
            return bubble
        }
        for slot in refilled.indices where refilled[slot] == nil && !unclaimed.isEmpty {
            refilled[slot] = unclaimed.removeFirst()
        }
        return refilled
    }
}
