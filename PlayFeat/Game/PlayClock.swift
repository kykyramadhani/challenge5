//
//  PlayClock.swift
//  PlayFeat
//
//  Seconds of unpaused play. Every deadline is measured on it, so pausing needs
//  no compensation anywhere: the clock stops and the deadlines stay valid.
//

import Foundation

struct PlayClock {
    /// The largest slice of wall clock a single tick may credit. A stall — or
    /// coming back from a pause or the background — must not hand the player
    /// a dish failure they never saw coming. Same guard, for the same reason,
    /// as `HoverDetector.maxFrameGap`.
    static let maxTickDelta: TimeInterval = 0.25

    private(set) var elapsed: TimeInterval = 0
    private var lastTick: TimeInterval

    init(wallTime: TimeInterval) {
        lastTick = wallTime
    }

    /// Credits the wall-clock time since the previous tick, capped.
    mutating func advance(to wallTime: TimeInterval) {
        elapsed += min(wallTime - lastTick, Self.maxTickDelta)
        lastTick = wallTime
    }

    /// Moves past `wallTime` without crediting it — while paused or after the
    /// run ends. Still recorded, so resuming doesn't credit the whole pause
    /// to the dish in one go.
    mutating func hold(at wallTime: TimeInterval) {
        lastTick = wallTime
    }

    mutating func reset() {
        elapsed = 0
    }
}
