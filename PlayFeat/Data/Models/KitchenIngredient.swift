//
//  KitchenIngredient.swift
//  PlayFeat
//
//  The space-kitchen menu from the Figma ingredient sheet: what each raw
//  ingredient looks like, how it has to be prepared, and what it looks like
//  once it is. The raw value is the stable ID; images are looked up by name.
//

import Foundation

nonisolated enum KitchenIngredient: String, CaseIterable, Codable {
    case glowingMushroom
    case coralLettuce
    case bubbleTuber
    case starJelly
    case tentacle

    var preparation: Preparation {
        switch self {
        case .glowingMushroom: .chop
        case .coralLettuce: .soup
        case .bubbleTuber: .boil
        case .tentacle: .fry
        case .starJelly: .none
        }
    }

    /// The one routing rule: the portal Procurement hands this ingredient
    /// over through. Anything the Chef still has to cook or fry goes to the
    /// kitchen raw; anything ready to serve — desserts as they are, chopped
    /// vegetables once sliced — goes straight to Front House.
    var deliveryPortal: DropZone {
        preparation.isChefWork ? .kitchenPortal : .frontHousePortal
    }

    /// Whether it leaves Procurement sliced (chopped on the board first)
    /// rather than as it came out of its crate.
    var isDeliveredSliced: Bool { preparation == .chop }

    var rawImageName: String {
        switch self {
        case .glowingMushroom: "MushroomRaw"
        case .coralLettuce: "CoralLettuceRaw"
        case .bubbleTuber: "BubbleTuberRaw"
        case .starJelly: "StarJelly"
        case .tentacle: "TentacleRaw"
        }
    }

    /// The ingredient once Procurement or the Chef has prepared it.
    var preparedImageName: String {
        switch self {
        case .glowingMushroom: "MushroomSliced"
        case .coralLettuce: "CoralLettuceSoup"
        case .bubbleTuber: "BubbleTuberBoiled"
        case .starJelly: "StarJelly"
        case .tentacle: "TentacleFried"
        }
    }
}

/// What has to happen to an ingredient before it can be served, and so where
/// Procurement sends it.
nonisolated enum Preparation {
    /// Procurement slices it on the cutting board, then sends it to Front House.
    case chop
    /// The Chef boils it in the boiling pot; Procurement sends it raw
    /// through the kitchen portal.
    case boil
    /// The Chef stirs it into soup in the broth pot; sent raw to the Chef.
    case soup
    /// The Chef fries it; Procurement sends it raw through the kitchen portal.
    case fry
    /// Served as it is; Procurement sends it straight to Front House.
    case none

    /// Done by the Chef after Procurement hands the ingredient over raw.
    var isChefWork: Bool { chefStation != nil }

    /// Where in the Chef's kitchen it is cooked: the leftmost pot boils, the
    /// middle one makes soup from broth, the fryer fries.
    var chefStation: DropZone? {
        switch self {
        case .boil: .boilingPot
        case .soup: .brothPot
        case .fry: .fryer
        case .chop, .none: nil
        }
    }

    /// The order-ticket icon under the ingredient, if any.
    var iconName: String? {
        switch self {
        case .chop: "IconChop"
        case .boil, .soup: "IconPot"
        case .fry: "IconFry"
        case .none: nil
        }
    }
}
