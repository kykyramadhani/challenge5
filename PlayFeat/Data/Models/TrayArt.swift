//
//  TrayArt.swift
//  PlayFeat
//
//  How things sit on the food tray (ompreng) art: the dirt, centred, so
//  washing can fade it out; the four compartments Front House fills; and the
//  drink glass standing at its bottom-left corner. Proportions measured off
//  the Figma dirty-tray bubble and the Front House tray (702:15431).
//

import CoreGraphics

enum TrayArt {
    static let trayImage = "TrayClean"
    static let dirtImage = "TrayDirt"
    static let drinkImage = "GlassFull"
    /// The tray's width over its height.
    static let aspectRatio: CGFloat = 336.9 / 273.8

    static func dirtSize(onTray tray: CGSize) -> CGSize {
        CGSize(width: tray.width * 0.765, height: tray.height * 0.774)
    }

    /// A compartment's centre, as a fraction of the tray's size.
    static func center(of compartment: TrayCompartment) -> CGPoint {
        switch compartment {
        case .vegetable: CGPoint(x: 0.231, y: 0.267)
        case .dessert: CGPoint(x: 0.693, y: 0.269)
        case .soup: CGPoint(x: 0.231, y: 0.728)
        case .main: CGPoint(x: 0.693, y: 0.729)
        }
    }

    /// A dish in a compartment, as a fraction of the tray's width.
    static let dishWidth: CGFloat = 0.3
    /// The drink glass at the tray's bottom-left corner, from the Front House
    /// tickets: its centre and size as fractions of the tray.
    static let drinkCenter = CGPoint(x: -0.03, y: 0.94)
    static let drinkSize = CGSize(width: 0.204, height: 0.35)
}
