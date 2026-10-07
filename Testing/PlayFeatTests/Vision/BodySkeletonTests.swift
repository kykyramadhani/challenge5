//
//  BodySkeletonTests.swift
//  PlayFeatTests
//
//  Split out of GetCookingTests.swift (created by Kyky on 11/08/26).
//

import Testing
import Foundation
import CoreGraphics
@testable import PlayFeat

/// The upper-body skeleton that gets drawn.
struct BodySkeletonTests {

    private func body(hips: Bool) -> HandPoseManager.BodyCandidate {
        HandPoseManager.BodyCandidate(
            head: CGPoint(x: 0.5, y: 0.85), // never drawn — see the test below
            leftShoulder: CGPoint(x: 0.4, y: 0.7),
            rightShoulder: CGPoint(x: 0.6, y: 0.7),
            leftHip: hips ? CGPoint(x: 0.42, y: 0.4) : nil,
            rightHip: hips ? CGPoint(x: 0.58, y: 0.4) : nil,
            leftWrist: nil,
            rightWrist: nil
        )
    }

    /// Framed from the chest up: just the shoulder line, no dangling bones to
    /// hips that were never seen.
    @Test func shouldersAloneDrawOneBone() {
        #expect(body(hips: false).chains == [[CGPoint(x: 0.4, y: 0.7), CGPoint(x: 0.6, y: 0.7)]])
    }

    /// Hips in shot close the torso: shoulder line, both sides, hip line.
    @Test func hipsCloseTheTorso() {
        #expect(body(hips: true).chains.count == 4)
    }

    /// Legs are never read, so nothing below the hips can ever be drawn.
    @Test func nothingIsDrawnBelowTheHips() {
        let lowest = body(hips: true).chains.flatMap { $0 }.map(\.y).min()

        #expect(lowest == 0.4, "hip line is the bottom of the skeleton")
    }

    /// The head drives the seat check but is not part of the skeleton, so it
    /// must never turn up in the drawn chains.
    @Test func theHeadIsNotDrawn() {
        let drawn = Set(body(hips: true).chains.flatMap { $0 })

        #expect(!drawn.contains(CGPoint(x: 0.5, y: 0.85)))
    }
}
