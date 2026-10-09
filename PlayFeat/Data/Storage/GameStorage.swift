//
//  GameStorage.swift
//  GetCooking
//
//  Created by Owen Limantoro on 23/08/26.
//

import Foundation

struct GameStorage {
    static let coinKey = "coins"
    static let scoreKey = "highscore"
    
    static var coins: Int {
        get {
            UserDefaults.standard.integer(forKey: self.coinKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: self.coinKey)
        }
    }
    
    static var highscore: Int {
        get {
            UserDefaults.standard.integer(forKey: self.scoreKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: self.scoreKey)
        }
    }

    /// Banks a finished run: its coins, and its dish count if that beats the
    /// best so far.
    static func record(_ result: GameResult) {
        coins += result.totalCoins
        // Checked before the write, so it compares against the *previous*
        // best rather than the value about to be stored.
        if result.newHighScore {
            highscore = result.totalDishesServed
        }
    }
}
