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
    /// The PlayFeat sign, shown at launch.
    case title
    /// Choosing Procurement, Chef or Front House.
    case roleSelect
    /// A Procurement shift.
    case procurement
    /// A Chef shift.
    case chef
    /// A Front House shift.
    case frontHouse
    /// The end-of-shift report, carrying the score of the role just played.
    case shiftReport(ShiftReport)
    case mainMenu
    case shop
    case gameplay
    /// The end-of-run paycheck, carrying the finished run's outcome.
    case postGame(GameResult)
}
