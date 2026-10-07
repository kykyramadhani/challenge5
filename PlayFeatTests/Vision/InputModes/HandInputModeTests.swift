//
//  HandInputModeTests.swift
//  PlayFeatTests
//
//  The two input modes, and how the Settings values pick between them.
//

import Testing
import Foundation
import CoreGraphics
@testable import PlayFeat

struct HandInputModeTests {

    private let leftWrist = CGPoint(x: 0.4, y: 0.5)
    private let rightWrist = CGPoint(x: 0.6, y: 0.5)

    private func body(left: CGPoint?, right: CGPoint?) -> HumanBodyPoseManager.BodyCandidate {
        HumanBodyPoseManager.BodyCandidate(
            head: CGPoint(x: 0.5, y: 0.8),
            leftShoulder: CGPoint(x: 0.35, y: 0.6),
            rightShoulder: CGPoint(x: 0.65, y: 0.6),
            leftHip: nil,
            rightHip: nil,
            leftWrist: left,
            rightWrist: right
        )
    }

    // MARK: - Two hands

    @Test func twoHandModeUsesBothWrists() {
        let mode = TwoHandMode()
        let both = body(left: leftWrist, right: rightWrist)

        #expect(mode.handCount == 2)
        #expect(mode.playerWrists(of: both) == [leftWrist, rightWrist])
        #expect(mode.seesEveryHand(on: both))
    }

    /// One hand up is not enough when the game is played with two.
    @Test func twoHandModeMissesAHandThatIsDown() {
        let mode = TwoHandMode()
        #expect(!mode.seesEveryHand(on: body(left: leftWrist, right: nil)))
    }

    // MARK: - One hand

    @Test func oneHandModeUsesOnlyTheChosenWrist() {
        let both = body(left: leftWrist, right: rightWrist)

        #expect(OneHandMode(hand: .left).playerWrists(of: both) == [leftWrist])
        #expect(OneHandMode(hand: .right).playerWrists(of: both) == [rightWrist])
        #expect(OneHandMode(hand: .right).handCount == 1)
    }

    /// The other hand being up doesn't stand in for the chosen one.
    @Test func oneHandModeNeedsTheChosenHandSpecifically() {
        let leftOnly = body(left: leftWrist, right: nil)

        #expect(OneHandMode(hand: .left).seesEveryHand(on: leftOnly))
        #expect(!OneHandMode(hand: .right).seesEveryHand(on: leftOnly))
        #expect(OneHandMode(hand: .right).playerWrists(of: leftOnly).isEmpty)
    }

    // MARK: - Setting

    @Test func theSettingPicksTheMatchingMode() {
        let twoHands = HandInputModeSetting.mode(isOneHand: false, preferredHand: .left)
        let oneHand = HandInputModeSetting.mode(isOneHand: true, preferredHand: .left)

        #expect(twoHands is TwoHandMode, "the preferred hand only matters in one-hand mode")
        #expect((oneHand as? OneHandMode)?.hand == .left)
    }

    /// What the Vision queue reads every frame: the stored values, with the
    /// right hand as the default when none was ever chosen.
    @Test func theStoredSettingDefaultsToTheRightHand() throws {
        let defaults = try #require(UserDefaults(suiteName: "HandInputModeTests"))
        defaults.removePersistentDomain(forName: "HandInputModeTests")
        #expect(HandInputModeSetting.stored(in: defaults) is TwoHandMode)

        defaults.set(true, forKey: HandInputModeSetting.isOneHandKey)
        #expect((HandInputModeSetting.stored(in: defaults) as? OneHandMode)?.hand == .right)

        defaults.set(HandSide.left.rawValue, forKey: HandInputModeSetting.preferredHandKey)
        #expect((HandInputModeSetting.stored(in: defaults) as? OneHandMode)?.hand == .left)
    }
}
