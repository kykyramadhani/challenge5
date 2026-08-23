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

}
