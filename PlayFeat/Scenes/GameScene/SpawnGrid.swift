//
//  SpawnGrid.swift
//  PlayFeat
//
//  Places ingredient bubbles without retries: the spawn area is cut into
//  brick-bonded cells at least one bubble (plus its float room) apart, and
//  each bubble takes a random cell and a random spot anywhere inside it.
//  Neighbours can't overlap by construction, so there's nothing to check and
//  try again. Pure, so it can be tested without a scene.
//

import CoreGraphics

nonisolated struct SpawnGrid {
    /// Where bubble *centres* may go. Already inset so a bubble at the edge
    /// stays fully inside the gameplay area.
    let area: CGRect

    /// Minimum distance between two bubble centres: two radii plus the room
    /// both need for their idle bob.
    let spacing: CGFloat

    /// Regions no bubble centre may enter: what's already on the board (the
    /// plate, the Reset button, bubbles still floating), each grown by how
    /// far a bubble reaches from its centre.
    var blocked: [CGRect] = []

    /// `count` positions, or nil when the board can't hold them all apart —
    /// too small or too crowded for this many bubbles.
    func positions<G: RandomNumberGenerator>(
        for count: Int,
        using generator: inout G
    ) -> [CGPoint]? {
        guard let cells = cellsHolding(count) else { return nil }
        return cells
            .shuffled(using: &generator)
            .prefix(count)
            .map { cell in
                CGPoint(
                    x: .random(in: cell.minX...cell.maxX, using: &generator),
                    y: .random(in: cell.minY...cell.maxY, using: &generator)
                )
            }
    }

    // MARK: - Cells

    /// The fewest columns that still hold `count` free cells. Fewer columns
    /// mean wider cells, and a wider cell gives its bubble more room to land
    /// anywhere inside it, so the board looks scattered instead of gridded.
    func cellsHolding(_ count: Int) -> [CGRect]? {
        let rows = Self.cellCount(along: area.height, spacing: spacing)
        let mostColumns = Self.cellCount(along: area.width, spacing: spacing)
        guard rows > 0, mostColumns > 0 else { return nil }

        for columns in 1...mostColumns {
            let free = cells(columns: columns, rows: rows).filter(isFree)
            if free.count >= count { return free }
        }
        return nil
    }

    /// Each cell is the range of centres one bubble may take. Cells in a row
    /// are `spacing` apart edge to edge, and so are the rows, so any two
    /// points in different cells are at least `spacing` apart, wherever in
    /// their cells they land.
    ///
    /// Brick bond: every other row is shifted half a cell and holds one cell
    /// fewer, so bubbles in neighbouring rows don't line up in columns.
    func cells(columns: Int, rows: Int) -> [CGRect] {
        // Spread the leftover room evenly: it becomes each cell's jitter.
        let pitchX = (area.width + spacing) / CGFloat(columns)
        let pitchY = (area.height + spacing) / CGFloat(rows)

        return (0..<rows).flatMap { row in
            let isShifted = !row.isMultiple(of: 2)
            let offset = isShifted ? pitchX / 2 : 0
            let count = isShifted ? columns - 1 : columns

            return (0..<max(count, 0)).map { column in
                CGRect(
                    x: area.minX + offset + CGFloat(column) * pitchX,
                    y: area.minY + CGFloat(row) * pitchY,
                    width: pitchX - spacing,
                    height: pitchY - spacing
                )
            }
        }
    }

    /// No part of the cell touches a blocked region, so a bubble anywhere in
    /// it is clear of everything.
    func isFree(_ cell: CGRect) -> Bool {
        !blocked.contains { Self.overlap($0, cell) }
    }

    /// Inclusive, unlike `CGRect.intersects`, which never reports an overlap
    /// for a zero-width rect — and a cell with no jitter room is exactly that.
    static func overlap(_ a: CGRect, _ b: CGRect) -> Bool {
        a.minX <= b.maxX && b.minX <= a.maxX
            && a.minY <= b.maxY && b.minY <= a.maxY
    }

    /// How many cells fit along `length` of centres with `spacing` between
    /// them: one per `spacing`, counting both ends.
    static func cellCount(along length: CGFloat, spacing: CGFloat) -> Int {
        guard length >= 0, spacing > 0 else { return 0 }
        return Int(((length + spacing) / spacing).rounded(.down))
    }
}
