//
//  ShiftAction.swift
//  PlayFeat
//  Created by Owen Limantoro on 21/10/26.
//
//  Something the player does in a shift that scores on their shift report.
//  Each role has its own. Only the player's own successful actions count —
//  never a wrong drop, and never the work of the stand-ins for other roles.
//

enum ShiftAction: CaseIterable, Hashable {
    // MARK: Procurement

    /// An ingredient finished on the cutting board, or a dirty tray scrubbed
    /// clean.
    case ingredientCutOrTrayWashed
    /// An ingredient the active order wanted, sent through a portal.
    case ingredientSent

    // MARK: Chef

    /// Soup the active order wanted, sent to Front House.
    case soupCooked
    /// A boiled or fried dish the active order wanted, sent to Front House.
    case boiledOrFried

    // MARK: Front House

    /// An order served with everything it needed.
    case orderServed
    /// A drink poured and served to the order that wanted it.
    case beverageMade

    var role: KitchenRole {
        switch self {
        case .ingredientCutOrTrayWashed, .ingredientSent: .procurement
        case .soupCooked, .boiledOrFried: .chef
        case .orderServed, .beverageMade: .frontHouse
        }
    }

    /// Each role's main job is worth two points; its supporting job, one.
    var points: Int {
        switch self {
        case .ingredientCutOrTrayWashed, .soupCooked, .orderServed: 2
        case .ingredientSent, .boiledOrFried, .beverageMade: 1
        }
    }
}
