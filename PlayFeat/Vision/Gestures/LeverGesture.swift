//
//  LeverGesture.swift
//  PlayFeat
//
//  The drink dispenser's tap: pinch the handle and pull it left to open, push
//  it back right to close. Distance is measured from where the pinch took
//  hold, so the lever works wherever the hand is. Only a hand seen this
//  frame and pinching moves it; one coasting through a tracking gap holds
//  the lever where it is, and letting go of the pinch leaves the tap as it is.
//

import CoreGraphics

nonisolated struct LeverGesture {
    enum Event: Equatable {
        case opened, closed
    }

    /// How far (view points) the handle has to travel to open or close.
    let travel: CGFloat
    private(set) var isOpen = false
    /// Where the pinch took hold, or where the last open or close happened.
    private var anchorX: CGFloat?

    init(travel: CGFloat) {
        self.travel = travel
    }

    /// Feeds one frame of the hand on the handle (nil when there is none).
    /// Returns `.opened` or `.closed` on the frame the tap changes.
    mutating func observe(x: CGFloat?, isPinching: Bool, isReliable: Bool) -> Event? {
        guard isReliable else { return nil }
        guard let x, isPinching else {
            anchorX = nil
            return nil
        }
        guard let anchor = anchorX else {
            anchorX = x
            return nil
        }
        let pull = x - anchor
        if !isOpen, pull <= -travel {
            return flip(to: true, at: x)
        }
        if isOpen, pull >= travel {
            return flip(to: false, at: x)
        }
        return nil
    }

    private mutating func flip(to open: Bool, at x: CGFloat) -> Event {
        isOpen = open
        anchorX = x
        return open ? .opened : .closed
    }
}
