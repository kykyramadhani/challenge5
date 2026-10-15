//
//  IngredientCardPicker.swift
//  PlayFeat
//
//  Decides what goes on the three floating ingredient cards. The aim is two
//  cards for the order being worked on and one for an order further down the
//  rail, so the player always has something useful to grab and a reason to
//  look ahead. Only the card that was used is ever re-dealt.
//

import Foundation

enum IngredientCardPicker {
    static let cardCount = 3
    static let cardsForCurrentOrder = 2

    /// Deals all three cards from scratch, one slot at a time.
    static func deal(current: [KitchenIngredient],
                     upcoming: [KitchenIngredient]) -> [KitchenIngredient] {
        var cards: [KitchenIngredient] = []
        for _ in 0..<cardCount {
            cards.append(replacement(among: cards, current: current, upcoming: upcoming))
        }
        return cards
    }

    /// The ingredient for one empty slot, given the cards that stay put.
    ///
    /// - Parameters:
    ///   - others: the cards in the other slots, which never change.
    ///   - current: what the active order still needs from Procurement.
    ///   - upcoming: what the orders behind it need.
    static func replacement(among others: [KitchenIngredient],
                            current: [KitchenIngredient],
                            upcoming: [KitchenIngredient]) -> KitchenIngredient {
        let forCurrent = others.filter(current.contains).count
        if forCurrent < cardsForCurrentOrder, let pick = pick(from: current, avoiding: others) {
            return pick
        }
        if let pick = pick(from: upcoming, avoiding: others) { return pick }
        // More ingredients than cards: something unused always remains.
        return pick(from: KitchenIngredient.allCases, avoiding: others) ?? .starJelly
    }

    /// An ingredient from `pool` that isn't on any other card. The three
    /// cards are always three different ingredients, even when an order
    /// needs two of the same: the card simply comes back after it's used.
    private static func pick(from pool: [KitchenIngredient],
                             avoiding others: [KitchenIngredient]) -> KitchenIngredient? {
        pool.filter { !others.contains($0) }.randomElement()
    }
}
