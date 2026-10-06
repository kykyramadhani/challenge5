//
//  SoundEffects.swift
//  GetCooking
//
//  Created by Owen Limantoro on 22/08/26.
//

import Foundation

// MARK: - Sound catalog

/// Every sound in the game. The raw value is the file name (without extension)
/// exactly as it appears in Resource/Sound.
enum SoundEffect: String, CaseIterable {
    case addPoint        = "add_point"          // player earns a point
    case bell            = "bell_2x"            // dish finished / order up
    case bubbleGrab      = "bubble_grab"        // pick up an ingredient/item
    case bubblePut       = "bubble_put"         // place an ingredient down
    case clockRunningOut = "clock_running_out"  // low-time warning (looping)
    case countdown       = "countdown321"       // start of a round
    case loseHeart       = "lose_heart"         // mistake / dropped order
    case putOrder        = "put_order"          // submit a completed order
    case reset           = "reset"              // level restart / game reset
    case uiClick         = "ui_click"           // menu button pressed
    case wrongIngredient = "wrong_ingredients"  // a wrong ingredient placed on the plate
    case scuffleCloud    = "scuffle_cloud"      // the puff of smoke when a dish is finished
}
