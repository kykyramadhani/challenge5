//
//  DropTargetTests.swift
//  PlayFeatTests
//
//  Letting go near a place is enough: the nearest place that takes the item
//  within reach gets it, and too far away nothing does.
//

import CoreGraphics
import Testing
@testable import PlayFeat

struct DropTargetTests {
    private let tray = CGRect(x: 100, y: 100, width: 200, height: 150)
    private let portal = CGRect(x: 600, y: 100, width: 100, height: 300)

    private func target(at point: CGPoint) -> DropZone? {
        ProcurementLayout.nearestTarget(to: point, among: [(.assemblyTray, tray), (.procurementPortal, portal)],
                                        reach: 80)
    }

    @Test func insideATargetLandsThere() {
        #expect(target(at: CGPoint(x: 150, y: 150)) == .assemblyTray)
    }

    /// Just off the tray's edge still counts.
    @Test func nearATargetLandsThere() {
        #expect(target(at: CGPoint(x: 360, y: 200)) == .assemblyTray)
        #expect(target(at: CGPoint(x: 200, y: 310)) == .assemblyTray)
    }

    @Test func betweenTwoTargetsTheNearerWins() {
        #expect(target(at: CGPoint(x: 560, y: 200)) == .procurementPortal)
    }

    @Test func tooFarFromEverythingLandsNowhere() {
        #expect(target(at: CGPoint(x: 450, y: 600)) == nil)
    }
}
