//
//  HandInputSource.swift
//  PlayFeat
//
//  Where the game scene gets the player's hands from. `HandPoseManager` reads
//  them from the camera; tests (and later the Simulator) can script them
//  instead, so gameplay runs without a camera.
//
//  Kept to what `GameScene` reads. Camera control (`start`/`stop`), permission
//  and the body pose stay on `HandPoseManager` for the views that need them.
//

import CoreGraphics

/// Class-bound so `GameScene` can hold it `weak`, like its other dependencies.
protocol HandInputSource: AnyObject {
    /// Every hand tracked this frame.
    var hands: [HandData] { get }

    /// The hand's cursor in view space (origin top-left, y-down).
    func cursor(for hand: HandData, in size: CGSize) -> CGPoint

    /// The hand's joints in view space, used to test what it is touching.
    func jointPoints(for hand: HandData, in size: CGSize) -> [CGPoint]
}

extension HandPoseManager: HandInputSource {}
