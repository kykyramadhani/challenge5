//
//  HandTracking.swift
//  GetCooking
//
//  Created by Owen Limantoro on 13/08/26.
//

import Foundation

enum HandState { case unknown, open, fist }

struct HandTracker {
    var previousState: HandState = .unknown
    var held: IngredientNode?
    var lastSeen: TimeInterval = 0
}
