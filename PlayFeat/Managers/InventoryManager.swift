//
//  InventoryManager.swift
//  GetCooking
//
//  Central manager providing SwiftData access for user inventory operations.
//

import Combine
import Foundation
import SwiftData
import SwiftUI

@MainActor
final class InventoryManager: ObservableObject {
    static let shared = InventoryManager()

    let container: ModelContainer
    private var context: ModelContext {
        container.mainContext
    }

    @Published private(set) var coinMultipliers: Int = 0

    init() {
        do {
            let schema = Schema([UserInventory.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.container = try ModelContainer(for: schema, configurations: [config])
            refresh()
        } catch {
            fatalError("Failed to initialize SwiftData ModelContainer: \(error)")
        }
    }

    /// Fetches or creates the single UserInventory record.
    private func getOrCreateInventory() -> UserInventory {
        let descriptor = FetchDescriptor<UserInventory>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let newInventory = UserInventory(id: "user_inventory", coinMultipliers: 0)
        context.insert(newInventory)
        try? context.save()
        return newInventory
    }

    /// Refreshes the published coinMultipliers value.
    func refresh() {
        let inventory = getOrCreateInventory()
        self.coinMultipliers = inventory.coinMultipliers
    }

    /// Adds the given number of multipliers to the inventory.
    func addMultipliers(_ count: Int) {
        let inventory = getOrCreateInventory()
        inventory.coinMultipliers += count
        try? context.save()
        refresh()
    }

    /// Consumes one coin multiplier if available. Returns true if consumed.
    @discardableResult
    func consumeMultiplier() -> Bool {
        let inventory = getOrCreateInventory()
        guard inventory.coinMultipliers > 0 else { return false }
        inventory.coinMultipliers -= 1
        try? context.save()
        refresh()
        return true
    }

    /// Returns the current multiplier count synchronously.
    func getMultiplierCount() -> Int {
        let inventory = getOrCreateInventory()
        return inventory.coinMultipliers
    }
}
