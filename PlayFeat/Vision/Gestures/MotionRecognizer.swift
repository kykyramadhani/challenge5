//
//  MotionRecognizer.swift
//  PlayFeat
//
//  Turns one hand's path into processing progress: chopping strokes on the
//  cutting board, scrubbing circles in the sink. Ported unchanged from the
//  GestureLab prototype, so the game counts motions exactly as playtested.
//  Only fed while the hand is inside an open work area, so ordinary carrying
//  can't trigger it.
//

import CoreGraphics
import Foundation

enum ProcessMotion {
    case circles, backAndForth, downStrokes, hold
}

struct MotionRecognizer {
    let motion: ProcessMotion
    /// Movement below this (points) is tracking jitter and ignored.
    let minStep: CGFloat
    /// Travel (points) one stroke needs.
    let strokeLength: CGFloat

    private var last: CGPoint?
    private var heading: CGFloat?
    private var spin: CGFloat = 0
    private var credited: CGFloat = 0
    private var travel: CGFloat = 0
    private var extreme: CGFloat?
    private var armed = true

    init(motion: ProcessMotion, minStep: CGFloat, strokeLength: CGFloat) {
        self.motion = motion
        self.minStep = minStep
        self.strokeLength = strokeLength
    }

    /// Forget the half-finished motion — the hand left the work area.
    mutating func reset() {
        self = MotionRecognizer(motion: motion, minStep: minStep, strokeLength: strokeLength)
    }

    /// Progress units this sample completes: circles, strokes, or seconds held.
    mutating func feed(_ point: CGPoint, dt: TimeInterval) -> Double {
        switch motion {
        case .hold: dt
        case .downStrokes: downStroke(point)
        case .circles, .backAndForth: turning(point)
        }
    }

    // MARK: - Circles and back-and-forth

    private mutating func turning(_ point: CGPoint) -> Double {
        guard let last else {
            self.last = point
            return 0
        }
        let step = hypot(point.x - last.x, point.y - last.y)
        guard step >= minStep else { return 0 }
        self.last = point

        let newHeading = atan2(point.y - last.y, point.x - last.x)
        defer { heading = newHeading }
        guard let heading else {
            travel = step
            return 0
        }
        let raw = newHeading - heading
        let turn = atan2(sin(raw), cos(raw)) // wrap to -π...π

        return motion == .circles ? circle(turn) : reversal(turn, step: step)
    }

    /// Counts net turning in one direction. Nothing counts until a quarter
    /// turn has built up, so a wobbly straight line can't add up to a circle;
    /// after that each bit of further turning counts once.
    private mutating func circle(_ turn: CGFloat) -> Double {
        // A sharp reversal is back-and-forth, never part of a circle.
        guard abs(turn) < .pi / 2 else {
            spin = 0
            credited = 0
            return 0
        }
        let next = spin + turn
        if next * spin < 0 { credited = 0 } // turning direction changed: start over
        spin = next
        let total = abs(spin)
        guard total >= .pi / 2, total > credited else { return 0 }
        defer { credited = total }
        return Double((total - credited) / (2 * .pi))
    }

    /// One stroke per sharp reversal (>120°) after enough travel.
    private mutating func reversal(_ turn: CGFloat, step: CGFloat) -> Double {
        guard abs(turn) > 2 * .pi / 3 else {
            travel += step
            return 0
        }
        let completed = travel >= strokeLength
        travel = step
        return completed ? 1 : 0
    }

    // MARK: - Downward strokes (scene space: y up)

    /// A stroke is `strokeLength` of drop from the highest point since the
    /// last one; the hand must lift half that again before the next counts.
    /// No speed requirement — slow strokes count the same as fast ones.
    private mutating func downStroke(_ point: CGPoint) -> Double {
        let y = point.y
        if armed {
            let top = max(extreme ?? y, y)
            extreme = top
            guard top - y >= strokeLength else { return 0 }
            armed = false
            extreme = y
            return 1
        }
        let bottom = min(extreme ?? y, y)
        extreme = bottom
        if y - bottom >= strokeLength / 2 {
            armed = true
            extreme = y
        }
        return 0
    }
}
