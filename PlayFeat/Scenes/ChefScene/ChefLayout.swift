//
//  ChefLayout.swift
//  PlayFeat
//
//  Where everything in the Chef's kitchen sits (Figma 616:8996): the
//  Procurement portal ingredients arrive through on the left, Front House on
//  the right, the five floating bubbles, and the counter with the boiling
//  pot, the broth pot and the fryer. The HUD, the panel and the Figma mapping
//  are shared with every role through `KitchenLayout`.
//

import CoreGraphics

struct ChefLayout: KitchenLayout {
    let size: CGSize

    // MARK: - Kitchen

    /// Only the part of the portal on screen; the art is cut the same way.
    var procurementPortal: CGRect { rect(x: 0, y: 723, width: 128, height: 311, .leading) }
    var frontHousePortal: CGRect { rect(x: 1248, y: 723, width: 242, height: 312, .trailing) }
    var counter: CGRect { rect(x: 285, y: 725, width: 887, height: 362, .center) }
    var trashCan: CGRect { rect(x: 1215, y: 528, width: 183, height: 199, .trailing) }

    /// The five floating ingredient bubbles, left to right.
    func bubble(_ slot: Int) -> CGRect {
        let origins: [CGPoint] = [
            CGPoint(x: 178, y: 486), CGPoint(x: 370, y: 307), CGPoint(x: 618, y: 516),
            CGPoint(x: 812, y: 348), CGPoint(x: 1018, y: 518),
        ]
        return rect(x: origins[slot].x, y: origins[slot].y, width: 161.3, height: 161.3, .center)
    }

    // MARK: - Stations

    /// The hob a pot stands on; the fryer has none.
    func stove(_ station: DropZone) -> CGRect? {
        switch station {
        case .boilingPot: rect(x: 370, y: 787, width: 200, height: 200, .center)
        case .brothPot: rect(x: 641, y: 787, width: 200, height: 200, .center)
        default: nil
        }
    }

    func pot(_ station: DropZone) -> CGRect {
        switch station {
        case .boilingPot: rect(x: 366, y: 772, width: 210, height: 187, .center)
        case .brothPot: rect(x: 625, y: 775, width: 238, height: 189, .center)
        default: rect(x: 905, y: 755, width: 210, height: 279, .center)
        }
    }

    /// The bar under a pot that fills while it boils or fries.
    func progressBar(_ station: DropZone) -> CGRect {
        let x: CGFloat = station == .fryer ? 911 : 366
        return rect(x: x, y: 983, width: 197.6, height: 31, .center)
    }

    /// The finished dish's bubble, over the top-right of its pot.
    func readyBubble(_ station: DropZone) -> CGRect {
        let origin: CGPoint = switch station {
        case .boilingPot: CGPoint(x: 492, y: 721)
        case .brothPot: CGPoint(x: 764, y: 730)
        default: CGPoint(x: 1010, y: 700)
        }
        return rect(x: origin.x, y: origin.y, width: 161.3, height: 161.3, .center)
    }

    // MARK: - Drops

    /// Every drop target and its area: a station is its pot and its hob.
    var dropTargets: [(zone: DropZone, rect: CGRect)] {
        let stations = ChefGame.stations.map { station in
            (zone: station, rect: stove(station).map { $0.union(pot(station)) } ?? pot(station))
        }
        return [(.trash, trashCan), (.frontHousePortal, frontHousePortal)] + stations
    }

    /// Where a dropped item flies to.
    func center(of zone: DropZone) -> CGPoint {
        switch zone {
        case .trash: trashCan.center
        case .frontHousePortal: frontHousePortal.center
        case .boilingPot, .brothPot, .fryer: pot(zone).center
        default: counter.center
        }
    }
}
