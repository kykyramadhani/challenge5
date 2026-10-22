//
//  ShiftReportTests.swift
//  PlayFeatTests
//  Created by Owen Limantoro on 21/10/26.
//
//  The shift report's rows and score: each role's two actions, weighted two
//  points for the main job and one for the supporting one.
//

import Testing
@testable import PlayFeat

struct ShiftReportTests {
    @Test(arguments: KitchenRole.allCases)
    func everyRoleReportsItsOwnTwoActionsMainJobFirst(role: KitchenRole) {
        let lines = ShiftReport(role: role).lines

        #expect(lines.map(\.action.points) == [2, 1])
        #expect(lines.allSatisfy { $0.action.role == role && $0.count == 0 })
    }

    @Test func theOverallScoreWeighsTheMainJobDouble() {
        var report = ShiftReport(role: .chef)
        for _ in 0..<3 { report.record(.soupCooked) }
        report.record(.boiledOrFried)

        #expect(report.lines.map(\.points) == [6, 1])
        #expect(report.overallScore == 7)
    }

    @Test func anotherRolesActionIsNotCounted() {
        var report = ShiftReport(role: .procurement)

        report.record(.orderServed)

        #expect(report.count(of: .orderServed) == 0)
        #expect(report.overallScore == 0)
    }
}
