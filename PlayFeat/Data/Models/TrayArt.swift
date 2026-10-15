//
//  TrayArt.swift
//  PlayFeat
//
//  How the dirt sits on the food tray (ompreng) art. The dirt is its own
//  image, centred on the tray, so washing can fade it out as the player
//  scrubs. Proportions measured off the Figma dirty-tray bubble.
//

import CoreGraphics

enum TrayArt {
    static let trayImage = "TrayClean"
    static let dirtImage = "TrayDirt"

    static func dirtSize(onTray tray: CGSize) -> CGSize {
        CGSize(width: tray.width * 0.765, height: tray.height * 0.774)
    }
}
