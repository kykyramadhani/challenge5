//
//  ServingTray.swift
//  PlayFeat
//
//  The food tray Front House assembles an order on: one finished dish per
//  compartment. Also how an order looks once it's all there, which the order
//  tickets and the table draw — with its drink beside it once that's served,
//  which happens on its own, not on the tray.
//

import Foundation

/// The four compartments of the food tray (ompreng).
nonisolated enum TrayCompartment: CaseIterable, Hashable {
    /// Top-left bowl: chopped vegetables (sliced mushroom, on its round plate).
    case vegetable
    /// Top-right box: star jelly.
    case dessert
    /// Bottom-left bowl: soup.
    case soup
    /// Bottom-right box: fried tentacle or boiled tuber.
    case main
}

nonisolated struct ServingTray: Equatable, Hashable {
    private(set) var dishes: [TrayCompartment: KitchenIngredient] = [:]
    private(set) var hasDrink = false

    init() {}

    /// The tray as it leaves the kitchen when everything on `order` is on
    /// it, with the drink beside it once that's been served.
    init(completing order: KitchenOrder) {
        for item in order.items { dishes[item.trayCompartment] = item }
        hasDrink = order.isDrinkServed
    }

    /// Whether a finished `dish` can go into `compartment` for `order`: its
    /// own compartment, still empty, and the order wants that dish there.
    func canPlace(_ dish: KitchenIngredient, in compartment: TrayCompartment, for order: KitchenOrder) -> Bool {
        dish.trayCompartment == compartment && dishes[compartment] == nil && order.items.contains(dish)
    }

    /// Every dish the order asks for is on the tray, and nothing else. The
    /// drink is served separately.
    func isComplete(for order: KitchenOrder) -> Bool {
        dishes == ServingTray(completing: order).dishes
    }

    mutating func place(_ dish: KitchenIngredient, in compartment: TrayCompartment) {
        dishes[compartment] = dish
    }
}
