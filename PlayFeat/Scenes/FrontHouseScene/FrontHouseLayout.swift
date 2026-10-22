//
//  FrontHouseLayout.swift
//  PlayFeat
//
//  Where everything at Front House sits (Figma 684:4679 and siblings): the
//  green bar table along the top with three tray tickets over it, the Chef
//  portal ingredients arrive through on the left and the Procurement portal
//  on the right, the clean-tray stand, the dispenser, the five floating
//  dishes, and the tray being assembled. The HUD, the panel and the Figma
//  mapping are shared with every role through `KitchenLayout`.
//

import CoreGraphics

struct FrontHouseLayout: KitchenLayout {
    static let ticketCount = 3

    let size: CGSize

    // MARK: - Counter

    var barTable: CGRect { rect(x: 333, y: -22, width: 1049, height: 165, .trailing) }
    var chefPortal: CGRect { rect(x: -126, y: 747, width: 269, height: 334, .leading) }
    /// Only the part of the portal on screen; the art is cut the same way.
    var procurementPortal: CGRect { rect(x: 1248, y: 723, width: 128, height: 311, .trailing) }
    var trayStand: CGRect { rect(x: -4, y: 522, width: 232, height: 192, .leading) }
    var trayCountBadge: CGRect { rect(x: 178, y: 671, width: 64, height: 64, .leading) }
    var dispenser: CGRect { rect(x: 1227, y: 445, width: 143.7, height: 288.3, .trailing) }
    /// The filled glass's bubble, beside the dispenser.
    var drinkBubble: CGRect { rect(x: 1164, y: 568, width: 161.3, height: 161.3, .trailing) }
    var assemblyTray: CGRect { rect(x: 532, y: 713, width: 336.9, height: 273.8, .center) }

    func area(of compartment: TrayCompartment) -> CGRect {
        switch compartment {
        case .vegetable: rect(x: 555.8, y: 732, width: 108.3, height: 108.3, .center)
        case .dessert: rect(x: 696.3, y: 736.8, width: 138.1, height: 99.6, .center)
        case .soup: rect(x: 555.8, y: 858.2, width: 108.3, height: 108.3, .center)
        case .main: rect(x: 696.3, y: 863, width: 138.1, height: 99.6, .center)
        }
    }

    /// The five floating dishes, left to right.
    func bubble(_ slot: Int) -> CGRect {
        let origins: [CGPoint] = [
            CGPoint(x: 119, y: 288), CGPoint(x: 323, y: 505), CGPoint(x: 571, y: 363),
            CGPoint(x: 810, y: 505), CGPoint(x: 1011, y: 363),
        ]
        return rect(x: origins[slot].x, y: origins[slot].y, width: 161.3, height: 161.3, .center)
    }

    // MARK: - Tickets and the table

    private static let ticketXs: [CGFloat] = [310, 667, 1024]

    /// The three tray tickets, left to right.
    func trayTicket(_ index: Int) -> CGRect {
        rect(x: Self.ticketXs[index], y: 0, width: 333, height: 265, .center)
    }

    /// A served order's tray on the table, where its ticket was, while its
    /// customer eats.
    func eatingTray(_ index: Int) -> CGRect {
        rect(x: Self.ticketXs[index] + 106, y: 20, width: 135.3, height: 110, .center)
    }

    /// The dirty tray's bubble there once they're done.
    func dirtyTrayBubble(_ index: Int) -> CGRect {
        rect(x: Self.ticketXs[index] + 64, y: 27, width: 237, height: 237, .center)
    }

    // MARK: - Drops

    /// Every drop target and its area.
    var dropTargets: [(zone: DropZone, rect: CGRect)] {
        let compartments = TrayCompartment.allCases.map { (zone: DropZone.compartment($0), rect: area(of: $0)) }
        let tickets = (0..<Self.ticketCount).map { (zone: DropZone.ticket($0), rect: trayTicket($0)) }
        return compartments + tickets + [
            (.assemblyTray, assemblyTray),
            (.procurementPortal, procurementPortal),
        ]
    }

    /// Where a dropped item flies to.
    func center(of zone: DropZone) -> CGPoint {
        switch zone {
        case let .compartment(compartment): area(of: compartment).center
        case let .ticket(index): eatingTray(index).center
        case .procurementPortal: procurementPortal.center
        default: assemblyTray.center
        }
    }
}
