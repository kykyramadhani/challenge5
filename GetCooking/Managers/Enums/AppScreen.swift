//
//  AppScreen.swift
//  GetCooking
//
//  Created by Owen Limantoro on 13/08/26.
//

import Foundation

enum AppScreen {
    case mainMenu
    /// The illustrated walkthrough, shown once before the seat check.
    case tutorial
    /// Sitting the player at a workable distance before play starts.
    case calibration
    case game
}
