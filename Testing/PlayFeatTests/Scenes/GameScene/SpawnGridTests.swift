//
//  SpawnGridTests.swift
//  PlayFeatTests
//
//  Where ingredient bubbles are placed: always apart, always inside the
//  gameplay area, never on the plate or the Reset button.
//

import Testing
import CoreGraphics
@testable import PlayFeat

struct SpawnGridTests {

    /// Same seed, same layout, so a failure can be replayed.
    struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            // SplitMix64
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    private let spacing: CGFloat = 228
    private let area = CGRect(x: 112, y: 466, width: 1152, height: 266)

    /// The most a dish ever spawns: the four-ingredient salad plus two decoys.
    private let mostBubbles = 6

    private func layouts(of grid: SpawnGrid, count: Int) -> [[CGPoint]] {
        (1...200).compactMap { seed in
            var generator = SeededGenerator(state: UInt64(seed))
            return grid.positions(for: count, using: &generator)
        }
    }

    // MARK: - Placement

    @Test func noTwoBubblesAreCloserThanTheSpacing() throws {
        let grid = SpawnGrid(area: area, spacing: spacing)

        for points in layouts(of: grid, count: mostBubbles) {
            for (i, a) in points.enumerated() {
                for b in points[(i + 1)...] {
                    #expect(a.distance(to: b) >= spacing - 0.001)
                }
            }
        }
    }

    @Test func everyBubbleStaysInsideTheArea() {
        let grid = SpawnGrid(area: area, spacing: spacing)

        for point in layouts(of: grid, count: mostBubbles).joined() {
            #expect(SpawnGrid.overlap(area, CGRect(origin: point, size: .zero)))
        }
    }

    @Test func noBubbleLandsInABlockedRegion() {
        let plate = CGRect(x: 500, y: 400, width: 400, height: 200)
        var grid = SpawnGrid(area: area, spacing: spacing)
        grid.blocked = [plate]

        for point in layouts(of: grid, count: 4).joined() {
            #expect(!plate.contains(point))
        }
    }

    /// Fresh layout every dish: the reason this isn't a fixed list of spots.
    @Test func differentDishesGetDifferentLayouts() {
        let grid = SpawnGrid(area: area, spacing: spacing)
        var first = SeededGenerator(state: 1)
        var second = SeededGenerator(state: 2)

        #expect(
            grid.positions(for: mostBubbles, using: &first)
                != grid.positions(for: mostBubbles, using: &second)
        )
    }

    // MARK: - Looking scattered, not gridded

    /// Only as many cells as the dish needs, so each is wide: a bubble can
    /// land anywhere across 100+ points instead of a few. On a 13" iPad.
    @Test func eachBubbleHasRoomToWander() throws {
        let grid = SpawnGrid(area: area, spacing: spacing)

        let cells = try #require(grid.cellsHolding(mostBubbles))

        #expect(cells.allSatisfy { $0.width >= 100 })
    }

    /// Brick bond: the shifted row starts half a cell in and holds one fewer,
    /// so its bubbles sit between the ones below instead of over them.
    @Test func shiftedRowsSitBetweenTheBricksBelow() {
        let grid = SpawnGrid(area: area, spacing: spacing)
        let pitch = (area.width + spacing) / 4

        let cells = grid.cells(columns: 4, rows: 2)
        let bottom = cells.filter { $0.minY == area.minY }
        let shifted = cells.filter { $0.minY > area.minY }

        #expect(bottom.count == 4)
        #expect(shifted.count == 3)
        #expect(abs(shifted[0].minX - (area.minX + pitch / 2)) < 0.001)
        #expect(shifted.allSatisfy { $0.maxX <= area.maxX })
    }

    // MARK: - Too little room

    @Test func moreBubblesThanFitGivesNoLayout() {
        let grid = SpawnGrid(area: area, spacing: spacing)
        var generator = SeededGenerator(state: 1)

        #expect(grid.positions(for: 20, using: &generator) == nil)
    }

    /// A band collapsed to a single line still holds a row of bubbles.
    @Test func aOneLineAreaStillPlacesBubbles() {
        let line = CGRect(x: 0, y: 300, width: 1000, height: 0)
        let grid = SpawnGrid(area: line, spacing: spacing)
        var generator = SeededGenerator(state: 1)

        let points = grid.positions(for: 4, using: &generator)

        #expect(points?.allSatisfy { $0.y == 300 } == true)
    }

    /// A cell with no room to jitter is a zero-width rect, which
    /// `CGRect.intersects` would never report as blocked.
    @Test func aZeroWidthCellCanStillBeBlocked() {
        let line = CGRect(x: 0, y: 300, width: 0, height: 0)
        var grid = SpawnGrid(area: line, spacing: spacing)
        grid.blocked = [CGRect(x: -10, y: 290, width: 20, height: 20)]
        var generator = SeededGenerator(state: 1)

        #expect(grid.positions(for: 1, using: &generator) == nil)
    }

    // MARK: - On real screens

    /// Every iPad the game ships on fits a full dish apart, without falling
    /// back to the even grid where bubbles may touch.
    @Test(arguments: [
        CGSize(width: 1376, height: 1032),  // iPad Pro 13"
        CGSize(width: 1210, height: 834),   // iPad Pro 11"
        CGSize(width: 1180, height: 820),   // iPad Air / iPad
        CGSize(width: 1133, height: 744),   // iPad mini
    ])
    @MainActor
    func everyIPadFitsAFullDish(screen: CGSize) {
        let scene = GameScene(size: screen)
        let radius = scene.ingredientRadius
        let floatRoom = radius * IngredientNode.floatAmplitudeFraction * 2
        let grid = SpawnGrid(area: scene.bubbleSpawnArea, spacing: radius * 2 + floatRoom)

        #expect(grid.cellsHolding(mostBubbles) != nil)
    }
}
