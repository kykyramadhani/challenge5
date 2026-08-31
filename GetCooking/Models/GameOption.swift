//
//  GameOption.swift
//  GetCooking
//
//  One entry in the main-menu game carousel.
//

import Foundation

enum GameType: String, Codable {
    case getCooking
}

struct GameOption: Identifiable, Hashable, Equatable {
    let id = UUID()
    let type: GameType
    let imageName: String
    let isAvailable: Bool
    var requiresCalibration = false
}

extension GameOption {
    static let all: [GameOption] = [
        GameOption(type: .getCooking, imageName: "GetCooking", isAvailable: true, requiresCalibration: true),
    ]
}
