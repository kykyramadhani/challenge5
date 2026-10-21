//
//  CarriedItem.swift
//  PlayFeat
//
//  What a player's hand can be holding, and where it came from — enough for
//  the role's game to decide whether a drop is valid and what it changes.
//  Shared by every role.
//

import Foundation

enum CarriedItem: Hashable {
    /// Raw, taken from one of the floating slots: a Procurement card or a
    /// Chef bubble.
    case ingredient(KitchenIngredient, cardSlot: Int)
    /// Sliced on the cutting board, ready for Front House.
    case sliced(KitchenIngredient)
    /// Boiled, fried or made into soup by the Chef, taken out of its pot.
    case cooked(KitchenIngredient)
    /// A finished dish from one of Front House's floating bubbles.
    case dish(KitchenIngredient, slot: Int)
    /// A glass filled at Front House's dispenser.
    case drink
    /// Front House's tray, with whatever is on it so far.
    case servingTray(ServingTray)
    case dirtyTray
    case cleanTray

    var imageName: String {
        switch self {
        case .ingredient(let ingredient, _): ingredient.rawImageName
        case .sliced(let ingredient), .cooked(let ingredient), .dish(let ingredient, _):
            ingredient.preparedImageName
        case .drink: TrayArt.drinkImage
        case .dirtyTray, .cleanTray, .servingTray: TrayArt.trayImage
        }
    }
}

/// The places a carried item can be let go over: the Procurement worktop's,
/// the Chef's three cooking stations, and Front House's tray and table.
nonisolated enum DropZone: Hashable {
    case cuttingBoard, sink, kitchenPortal, frontHousePortal, trash
    case boilingPot, brothPot, fryer
    /// Front House: where the tray is assembled, and one of its compartments.
    case assemblyTray
    case compartment(TrayCompartment)
    /// Front House: the active order's ticket, where its tray and its drink
    /// are served.
    case activeOrder
    case procurementPortal

    var isPortal: Bool { self == .kitchenPortal || self == .frontHousePortal || self == .procurementPortal }
}
