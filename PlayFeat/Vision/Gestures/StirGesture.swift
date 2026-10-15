//
//  StirGesture.swift
//  PlayFeat
//
//  Stirring soup in the zoomed-in broth pot: a pinched hand (holding the
//  ladle) circling over the pot. It's the sink's circle recognizer with the
//  opposite hand rule — washing counts open hands, stirring only pinched
//  ones — so it gets its own decision instead of reusing washing's.
//

enum StirGesture {
    /// What one hand's frame does to its half-finished stirring circle.
    enum Step: Equatable {
        /// Pinched and seen: its movement counts toward the circle.
        case stir
        /// Seen but not pinching: it let go of the ladle, so the circle
        /// starts over the next time it pinches.
        case restart
        /// Coasting through a tracking gap: keeps its circle, adds nothing.
        case hold
    }

    static func step(isPinching: Bool, isPredicted: Bool) -> Step {
        if isPredicted { return .hold }
        return isPinching ? .stir : .restart
    }
}
