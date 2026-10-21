//
//  ShiftCountdown.swift
//  PlayFeat
//
//  The 3-2-1 before a Procurement shift, kept in step with the camera: the
//  numbers tick while the camera warms up behind them, but play never starts
//  until there is a live picture to play with. If the camera is still not
//  ready when the count runs out, it holds on 1.
//

import Foundation

nonisolated enum ShiftCountdown {
    static let firstNumber = 3
    static let beat: TimeInterval = 1
    static var duration: TimeInterval { Double(firstNumber) * beat }

    /// The number to show `elapsed` seconds into the count, or nil once play
    /// may begin: the count is over and the camera is ready.
    static func number(after elapsed: TimeInterval, isCameraReady: Bool) -> Int? {
        let number = firstNumber - Int(max(0, elapsed) / beat)
        if number >= 1 { return number }
        return isCameraReady ? nil : 1
    }
}
