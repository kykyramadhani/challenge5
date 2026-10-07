//
//  Countdown.swift
//  PlayFeat
//
//  A deadline on the `PlayClock`, kept with its full length so a countdown ring
//  can draw how much is left.
//

import Foundation

struct Countdown {
    /// Nothing running yet: reads as already empty.
    static let none = Countdown(duration: 0, startingAt: 0)

    let duration: TimeInterval
    private let deadline: TimeInterval

    init(duration: TimeInterval, startingAt start: TimeInterval) {
        self.duration = duration
        self.deadline = start + duration
    }

    /// How much is left, 1 down to 0.
    func fractionLeft(at time: TimeInterval) -> CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat((deadline - time) / duration).vc_clamped(to: 0...1)
    }

    func hasRunOut(at time: TimeInterval) -> Bool {
        time >= deadline
    }

    /// Whole seconds still left — floored, so 3.7s left counts as 3.
    func wholeSecondsLeft(at time: TimeInterval) -> Int {
        max(0, Int(deadline - time))
    }
}
