//
//  HandClassifier.swift
//  PlayFeat
//
//  Created by Owen Limantoro on 08/10/26.
//
//  Reads one Vision hand observation: where the palm is, where the wrist is,
//  how big the hand looks, and how far apart the thumb and index fingertips
//  are — the pinch that grabs. Pure, so the pinch maths can be tested without
//  a camera.
//

import Vision
import CoreGraphics

/// A caseless enum: a namespace for functions, never instantiated.
/// `nonisolated` so frames can be classified on the camera's background queue.
nonisolated enum HandClassifier {

    /// What one Vision hand observation says about that hand.
    struct Classification {
        /// Palm centre, normalized Vision space.
        let location: CGPoint
        /// The hand's own wrist joint. Matched against the *body* detector's
        /// wrists to work out whose arm this hand is on.
        let wrist: CGPoint
        /// Wrist → knuckles, normalized. Doubles as a distance-from-camera
        /// cue: the same hand twice as far away measures half as long.
        let palmLength: CGFloat
        /// Thumb-tip to index-tip gap, in palm lengths. Nil when either tip
        /// was missing this frame — the hand is then treated as open, since a
        /// grab has to be seen to count.
        let pinchRatio: CGFloat?
        let skeleton: [[CGPoint]]
    }

    enum ClassificationError: Error {
        case noReliableWrist
        case noReliablePalm
    }
    
    /// Joint chains used both for the skeleton overlay and for the palm
    /// measurements below — wrist first, fingertip last.
    private static let fingerChains: [[VNHumanHandPoseObservation.JointName]] = [
        [.wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip],
        [.wrist, .indexMCP, .indexPIP, .indexDIP, .indexTip],
        [.wrist, .middleMCP, .middlePIP, .middleDIP, .middleTip],
        [.wrist, .ringMCP, .ringPIP, .ringDIP, .ringTip],
        [.wrist, .littleMCP, .littlePIP, .littleDIP, .littleTip]
    ]
    
    /// The gap between thumb tip and index-finger tip, in palm lengths —
    /// small means the two are pinched together, which is the grab gesture.
    ///
    /// Nil when either tip is missing, or the palm couldn't be measured: the
    /// caller reads that as "not grabbing", so a hand whose thumb drops out of
    /// tracking opens rather than clamping shut on whatever is nearby.
    static func pinchRatio(
        thumbTip: CGPoint?,
        indexTip: CGPoint?,
        palmLength: CGFloat
    ) -> CGFloat? {
        guard palmLength > 0, let thumbTip, let indexTip else { return nil }
        return distance(thumbTip, indexTip) / palmLength
    }

    
    static func classify(
        _ observation: VNHumanHandPoseObservation,
        jointConfidenceThreshold: Float
    ) throws -> Classification {
        let allPoints = try observation.recognizedPoints(.all)

        func point(_ name: VNHumanHandPoseObservation.JointName) -> CGPoint? {
            guard let joint = allPoints[name], joint.confidence >= jointConfidenceThreshold else {
                return nil
            }
            return CGPoint(x: joint.location.x, y: joint.location.y)
        }

        guard let wrist = point(.wrist) else { throw ClassificationError.noReliableWrist }

        let skeleton = fingerChains.map { $0.compactMap(point) }

        // Palm length = wrist → knuckles, the scale reference every other
        // measurement is divided by. Taking the largest available MCP keeps a
        // sane value when the middle knuckle briefly drops out.
        let knuckles: [VNHumanHandPoseObservation.JointName] = [.middleMCP, .indexMCP, .ringMCP, .littleMCP]
        let knucklePoints = knuckles.compactMap(point)
        guard let palmLength = knucklePoints.map({ distance(wrist, $0) }).max(), palmLength > 0 else {
            throw ClassificationError.noReliablePalm
        }

        // The grab gesture: thumb tip meeting index-finger tip. Only these two
        // joints matter — what the other three fingers are doing is ignored
        // entirely, so a fist and a flat palm both read as open.
        let pinch = pinchRatio(
            thumbTip: point(.thumbTip),
            indexTip: point(.indexTip),
            palmLength: palmLength
        )

        // Track the palm centre (wrist + knuckles) rather than including the
        // fingertips: the palm barely moves when the hand opens and closes, so
        // the cursor stays put at the exact moment the player clenches to grab.
        let palmPoints = [wrist] + knucklePoints
        let sum = palmPoints.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        let centre = CGPoint(x: sum.x / CGFloat(palmPoints.count), y: sum.y / CGFloat(palmPoints.count))

        return Classification(
            location: centre,
            wrist: wrist,
            palmLength: palmLength,
            pinchRatio: pinch,
            skeleton: skeleton
        )
    }

    /// Local rather than the shared `vc_distance`, which is main-actor by
    /// default and so can't be called from this `nonisolated` type.
    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
