//
//  CookingPot.swift
//  PlayFeat
//
//  What is in one of the Chef's three stations — the boiling pot, the broth
//  pot or the fryer — and how far along it is. Raw ingredients go in, a
//  cooked one comes out; the pot holds one at a time.
//

import Foundation

nonisolated enum CookingPot: Equatable {
    case empty
    /// Boiling or frying by itself, since `startedAt` (seconds of play).
    case cooking(KitchenIngredient, startedAt: TimeInterval)
    /// Waiting to be stirred into soup in the zoomed-in broth pot.
    case stirring(KitchenIngredient)
    /// Done: the cooked dish waits in the pot until a hand takes it out.
    case ready(KitchenIngredient)

    /// Whatever is in the pot, raw or cooked.
    var ingredient: KitchenIngredient? {
        switch self {
        case .empty: nil
        case let .cooking(ingredient, _), let .stirring(ingredient), let .ready(ingredient): ingredient
        }
    }

    var isEmpty: Bool { self == .empty }

    /// The cooked ingredient waiting to be taken out, if any.
    var readyIngredient: KitchenIngredient? {
        if case let .ready(ingredient) = self { ingredient } else { nil }
    }
}
