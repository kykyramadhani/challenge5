//
//  ShiftReport.swift
//  PlayFeat
//  Created by Owen Limantoro on 21/10/26.
//
//  The score of one shift for the role played. Each role's game keeps one and
//  records the player's actions into it; when the shift ends the report
//  screen gets a copy, so it needs no live reference back to the game.
//

struct ShiftReport: Hashable {
    let role: KitchenRole
    private var counts: [ShiftAction: Int] = [:]

    init(role: KitchenRole) {
        self.role = role
    }

    /// One row of the report: how many times the action was done, and what
    /// that scored.
    struct Line: Hashable {
        let action: ShiftAction
        let count: Int
        var points: Int { count * action.points }
    }

    /// Counts one more `action`. Another role's action is ignored: a report
    /// only ever scores the role it belongs to.
    mutating func record(_ action: ShiftAction) {
        guard action.role == role else { return }
        counts[action, default: 0] += 1
    }

    func count(of action: ShiftAction) -> Int {
        counts[action, default: 0]
    }

    /// This role's actions in report order, including ones never done (0×).
    var lines: [Line] {
        ShiftAction.allCases
            .filter { $0.role == role }
            .map { Line(action: $0, count: count(of: $0)) }
    }

    var overallScore: Int {
        lines.map(\.points).reduce(0, +)
    }
}
