//
//  HandIdentityTests.swift
//  PlayFeatTests
//
//  Split out of GetCookingTests.swift (created by Kyky on 11/08/26).
//

import Testing
import Foundation
import CoreGraphics
@testable import PlayFeat

struct HandIdentityTests {

    private let radius: CGFloat = 0.28

    /// The whole point of the matcher: Vision returns observations in no
    /// guaranteed order, so the same two hands can arrive swapped between
    /// frames. If identity followed array position, each hand would inherit
    /// whatever the other was dragging.
    @Test func reorderedObservationsKeepTheirIdentities() {
        let previous = [CGPoint(x: 0.2, y: 0.5),   // hand 0, left
                        CGPoint(x: 0.8, y: 0.5)]   // hand 1, right
        // Same two hands, reported in the opposite order this frame.
        let incoming = [CGPoint(x: 0.81, y: 0.51),
                        CGPoint(x: 0.19, y: 0.49)]

        let assignments = HandPoseManager.matchAssignments(
            newPositions: incoming, previousPositions: previous, radius: radius
        )

        #expect(assignments == [1, 0])
    }

    @Test func stationaryHandsKeepTheirIndices() {
        let previous = [CGPoint(x: 0.3, y: 0.4), CGPoint(x: 0.7, y: 0.6)]
        let assignments = HandPoseManager.matchAssignments(
            newPositions: previous, previousPositions: previous, radius: radius
        )
        #expect(assignments == [0, 1])
    }

    /// Each previous hand can only be claimed once, or one hand appearing in
    /// two places would eat both slots and orphan the other.
    @Test func onePreviousHandIsClaimedOnlyOnce() {
        let previous = [CGPoint(x: 0.5, y: 0.5)]
        let incoming = [CGPoint(x: 0.51, y: 0.5), CGPoint(x: 0.52, y: 0.5)]

        let assignments = HandPoseManager.matchAssignments(
            newPositions: incoming, previousPositions: previous, radius: radius
        )

        #expect(assignments == [0, nil], "second hand must be treated as new")
    }

    /// A hand that appears far from anything known is a new hand, not a
    /// teleporting old one.
    @Test func distantHandCountsAsNew() {
        let assignments = HandPoseManager.matchAssignments(
            newPositions: [CGPoint(x: 0.9, y: 0.9)],
            previousPositions: [CGPoint(x: 0.1, y: 0.1)],
            radius: radius
        )
        #expect(assignments == [nil])
    }

    @Test func firstFrameHasNothingToMatchAgainst() {
        let assignments = HandPoseManager.matchAssignments(
            newPositions: [CGPoint(x: 0.3, y: 0.3), CGPoint(x: 0.7, y: 0.7)],
            previousPositions: [],
            radius: radius
        )
        #expect(assignments == [nil, nil])
    }
}
