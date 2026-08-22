//
//  HandSide.swift
//  GetCooking
//
//  Which hand one-hand mode asks the player to calibrate with.
//

import Foundation

enum HandSide: String, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left: "Left Hand"
        case .right: "Right Hand"
        }
    }
}
