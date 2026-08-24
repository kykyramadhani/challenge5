//
//  ShopItem.swift
//  GetCooking
//
//  Model representing purchasable items in the shop.
//

import Foundation

struct ShopItem: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let price: Int
    let multiplier: Int
    let imageName: String

    static let coinMultiplier = ShopItem(
        id: "coin_multiplier_2x",
        name: "Coin Multiplier",
        description: "Multiplies total coins earned by 2 in your next game run!",
        price: 100,
        multiplier: 2,
        imageName: "Coin"
    )

    static let all: [ShopItem] = [
        .coinMultiplier
    ]
}
