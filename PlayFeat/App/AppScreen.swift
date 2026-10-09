//
//  AppScreen.swift
//  PlayFeat
//
//  The full-screen destinations ContentView can show. The tutorial and seat
//  check are not here on purpose: they are phases inside GameplayView, so the
//  camera stays mounted from the first tutorial page to the end of the run.
//

import Foundation

enum AppScreen: Hashable {
    case mainMenu
    case shop
    case gameplay
    /// The end-of-run paycheck, carrying the finished run's outcome.
    case postGame(GameResult)
}
