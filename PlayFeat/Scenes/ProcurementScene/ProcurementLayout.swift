//
//  ProcurementLayout.swift
//  PlayFeat
//
//  Where everything on the Procurement worktop sits. The HUD, the panel and
//  the Figma mapping are shared with every role through `KitchenLayout`.
//

import CoreGraphics

struct ProcurementLayout: KitchenLayout {
    let size: CGSize

    // MARK: - Worktop

    var sink: CGRect { rect(x: 5, y: 424, width: 230, height: 283, .leading) }
    var frontHousePortal: CGRect { rect(x: -118, y: 720, width: 242, height: 312, .leading) }
    var kitchenPortal: CGRect { rect(x: 1249, y: 723, width: 269, height: 334, .trailing) }
    var table: CGRect { rect(x: 355, y: 774, width: 675, height: 275, .center) }
    var cuttingBoard: CGRect { rect(x: 543, y: 813, width: 290, height: 184, .center) }
    var trashCan: CGRect { rect(x: 1210, y: 474, width: 183, height: 199, .trailing) }
    /// The bubble beside the Front House portal where trays come and go.
    var trayBubble: CGRect { rect(x: 30, y: 738, width: 237, height: 237, .leading) }

    /// The three floating ingredient cards, left to right.
    func card(_ slot: Int) -> CGRect {
        let xs: [CGFloat] = [342, 597.7, 853.5]
        return rect(x: xs[slot], y: 401, width: 223, height: 178, .center)
    }

    // MARK: - Zoomed-in panels

    /// The line a chop alternates across: halfway down the cutting panel's
    /// two dashed lanes, where one hand passes going down and the other going
    /// up.
    var chopReferenceY: CGFloat { rect(x: 471, y: 266, width: 94, height: 465, .center).midY }

    // MARK: - Drops

    /// The drop target under `point`. Checked smallest-first, so the board
    /// wins over the table it sits on.
    func dropZone(at point: CGPoint) -> DropZone? {
        let zones: [(DropZone, CGRect)] = [
            (.trash, trashCan),
            (.cuttingBoard, table),
            (.sink, sink),
            (.kitchenPortal, kitchenPortal),
            (.frontHousePortal, frontHousePortal),
        ]
        return zones.first { $0.1.contains(point) }?.0
    }

    /// Where a dropped item flies to. The Chef's stations aren't on this
    /// worktop, so they never come up here.
    func center(of zone: DropZone) -> CGPoint {
        switch zone {
        case .trash: trashCan.center
        case .cuttingBoard: cuttingBoard.center
        case .sink: sink.center
        case .kitchenPortal: kitchenPortal.center
        case .frontHousePortal: frontHousePortal.center
        case .boilingPot, .brothPot, .fryer: table.center
        }
    }
}
