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
    let title: String
    let type : GameType
    let imageName: String
    let isAvailable: Bool
    var highScore: Int?
    var requiresCalibration = false
}

extension GameOption {
    static let all: [GameOption] = [
        GameOption(title: "GetCooking", type: .getCooking, imageName: "GetCooking", isAvailable: true, highScore: 1000, requiresCalibration: true),
        GameOption(title: "Coming Soon", type: .getCooking, imageName: "ComingSoon", isAvailable: false, highScore: nil),
        GameOption(title: "Coming Soon", type: .getCooking, imageName: "ComingSoon", isAvailable: false, highScore: nil)
    ]
}
