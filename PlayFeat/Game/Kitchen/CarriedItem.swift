//
//  CarriedItem.swift
//  PlayFeat
//
//  What a player's hand can be holding, and where it came from — enough for
//  the role's game to decide whether a drop is valid and what it changes.
//  Shared by Procurement and the Chef.
//

import Foundation

enum CarriedItem: Equatable {
    /// Raw, taken from one of the floating slots: a Procurement card or a
    /// Chef bubble.
    case ingredient(KitchenIngredient, cardSlot: Int)
    /// Sliced on the cutting board, ready for Front House.
    case sliced(KitchenIngredient)
    /// Boiled, fried or made into soup by the Chef, taken out of its pot.
    case cooked(KitchenIngredient)
    case dirtyTray
    case cleanTray

    var imageName: String {
        switch self {
        case .ingredient(let ingredient, _): ingredient.rawImageName
        case .sliced(let ingredient), .cooked(let ingredient): ingredient.preparedImageName
        case .dirtyTray, .cleanTray: TrayArt.trayImage
        }
    }
}

/// The places a carried item can be let go over: the Procurement worktop's,
/// and the Chef's three cooking stations.
nonisolated enum DropZone: CaseIterable {
    case cuttingBoard, sink, kitchenPortal, frontHousePortal, trash
    case boilingPot, brothPot, fryer

    var isPortal: Bool { self == .kitchenPortal || self == .frontHousePortal }
}
