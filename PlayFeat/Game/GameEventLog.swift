//
//  GameEventLog.swift
//  PlayFeat
//
//  Every `GameEvent` of a run, numbered, so a consumer that remembers the last
//  number it handled can't miss two events landing between frames.
//

import Foundation

struct GameEventLog: Equatable {
    struct Entry: Equatable {
        /// Counts up from 1 and never repeats, so SwiftUI sees two identical
        /// events in a row as two changes.
        let number: Int
        let event: GameEvent
    }

    /// Kept whole: a run produces only a handful of events.
    private(set) var entries: [Entry] = []

    var latest: Entry? { entries.last }

    mutating func record(_ event: GameEvent) {
        entries.append(Entry(number: (latest?.number ?? 0) + 1, event: event))
    }

    func entries(after number: Int) -> [Entry] {
        entries.filter { $0.number > number }
    }

    func count(of event: GameEvent) -> Int {
        entries.count { $0.event == event }
    }
}
