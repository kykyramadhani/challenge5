//
//  GameStorage.swift
//  GetCooking
//
//  Created by Owen Limantoro on 23/08/26.
//

import Foundation

struct GameStorage {
    static var coins: Int {
        get {
            UserDefaults.standard.integer(forKey: "coins")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "coins")
        }
    }
    
    static var highscore: Int {
        get {
            UserDefaults.standard.integer(forKey: "highscore")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "highscore")
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
