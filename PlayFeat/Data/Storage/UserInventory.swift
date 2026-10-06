//
//  UserInventory.swift
//  GetCooking
//
//  SwiftData model tracking items owned by the player, including coin multipliers.
//

import Foundation
import SwiftData

@Model
final class UserInventory {
    @Attribute(.unique) var id: String
    var coinMultipliers: Int

    init(id: String = "user_inventory", coinMultipliers: Int = 0) {
        self.id = id
        self.coinMultipliers = coinMultipliers
    }
}
