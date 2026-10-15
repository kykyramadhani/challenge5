//
//  ChopDetectorTests.swift
//  PlayFeatTests
//
//  The handshake chop: one count per real swap of the two hands across the
//  reference line, never for one hand alone, never twice for the same swap,
//  and never from predicted or unidentified hands. View space, y down.
//

import Testing
import CoreGraphics
@testable import PlayFeat

struct ChopDetectorTests {
    private let line: CGFloat = 500
    private let band: CGFloat = 30
    private let up: CGFloat = 400
    private let down: CGFloat = 600

    private func detector() -> ChopDetector {
        ChopDetector(referenceY: line, deadBand: band)
    }

    private func seen(_ y: CGFloat) -> ChopDetector.HandSample {
        .init(y: y, isReliable: true)
    }

    private func chops(in verdicts: [ChopDetector.Verdict]) -> Int {
        verdicts.filter { if case .chop = $0 { true } else { false } }.count
    }

    // MARK: - Counting

    @Test func leftUpRightDownThenLeftDownRightUpIsOneChop() {
        var chopper = detector()
        let first = chopper.observe(left: seen(up), right: seen(down))
        let second = chopper.observe(left: seen(down), right: seen(up))

        #expect(first == .armed(.leftUpRightDown))
        #expect(second == .chop(from: .leftUpRightDown, to: .leftDownRightUp))
    }

    @Test func theReverseSequenceIsOneChopToo() {
        var chopper = detector()
        _ = chopper.observe(left: seen(down), right: seen(up))
        let second = chopper.observe(left: seen(up), right: seen(down))

        #expect(second == .chop(from: .leftDownRightUp, to: .leftUpRightDown))
    }

    @Test func consecutiveAlternationsCountOneEach() {
        var chopper = detector()
        var verdicts: [ChopDetector.Verdict] = []
        for swap in 0...5 {
            let leftUp = swap.isMultiple(of: 2)
            // Several frames per pose, as a real hand holds a pose a moment.
            for _ in 0..<4 {
                verdicts.append(chopper.observe(left: seen(leftUp ? up : down), right: seen(leftUp ? down : up)))
            }
        }
        #expect(chops(in: verdicts) == 5)
    }

    @Test func stayingInOnePoseNeverRepeats() {
        var chopper = detector()
        _ = chopper.observe(left: seen(up), right: seen(down))
        _ = chopper.observe(left: seen(down), right: seen(up))
        let held = (0..<20).map { _ in chopper.observe(left: seen(down), right: seen(up)) }

        #expect(chops(in: held) == 0)
        #expect(held.allSatisfy { $0 == .holding(.leftDownRightUp) })
    }

    // MARK: - Not a chop

    @Test func bothHandsOnTheSameSideNeverChop() {
        var chopper = detector()
        let verdicts = [
            chopper.observe(left: seen(up), right: seen(up)),
            chopper.observe(left: seen(down), right: seen(down)),
            chopper.observe(left: seen(up), right: seen(up)),
        ]
        #expect(chops(in: verdicts) == 0)
        #expect(verdicts.allSatisfy { $0 == .rejected(.sameHeight) })
    }

    @Test func movingOnlyOneHandNeverChops() {
        var chopper = detector()
        var verdicts = [chopper.observe(left: seen(up), right: seen(down))]
        for _ in 0..<5 {
            verdicts.append(chopper.observe(left: seen(down), right: seen(down)))
            verdicts.append(chopper.observe(left: seen(up), right: seen(down)))
        }
        #expect(chops(in: verdicts) == 0)
    }

    /// Hovering on the line can't chatter: inside the band a hand keeps the
    /// height it had.
    @Test func jitterInsideTheBandChangesNothing() {
        var chopper = detector()
        _ = chopper.observe(left: seen(up), right: seen(down))
        let jitter = (0..<20).map { step in
            chopper.observe(left: seen(line + (step.isMultiple(of: 2) ? -band + 1 : band - 1)),
                            right: seen(line + (step.isMultiple(of: 2) ? band - 1 : -band + 1)))
        }
        #expect(chops(in: jitter) == 0)
    }

    /// Going through "both in the middle" on the way across is normal and
    /// still ends in exactly one chop.
    @Test func passingThroughTheBandStillCountsOnce() {
        var chopper = detector()
        let path: [(CGFloat, CGFloat)] = [(up, down), (line, line), (down, line), (down, up), (down, up)]
        let verdicts = path.map { chopper.observe(left: seen($0.0), right: seen($0.1)) }
        #expect(chops(in: verdicts) == 1)
    }

    // MARK: - Tracking gaps

    /// A predicted or unidentified hand pauses the gesture: no chop from it,
    /// and none lost either — the swap counts once real readings return.
    @Test func anUnreliableHandPausesWithoutLosingTheSequence() {
        var chopper = detector()
        _ = chopper.observe(left: seen(up), right: seen(down))

        let predicted = chopper.observe(left: .init(y: down, isReliable: false), right: seen(up))
        let back = chopper.observe(left: seen(down), right: seen(up))

        #expect(predicted == .rejected(.handUnreliable))
        #expect(back == .chop(from: .leftUpRightDown, to: .leftDownRightUp))
    }

    /// A hand lost past the grace period resets the sequence, so the pose
    /// before the loss can't pair with one after it into a phantom chop.
    @Test func losingAHandResetsWithoutAPhantomChop() {
        var chopper = detector()
        _ = chopper.observe(left: seen(up), right: seen(down))

        let lost = chopper.observe(left: nil, right: seen(up))
        let back = chopper.observe(left: seen(down), right: seen(up))

        #expect(lost == .rejected(.handMissing))
        #expect(back == .armed(.leftDownRightUp))
    }

    // MARK: - One-hand mode

    @Test func oneHandUpAndDownCountsEachSwap() {
        var chopper = detector()
        let verdicts = [up, up, down, down, up].map { chopper.observe(hand: seen($0)) }
        #expect(chops(in: verdicts) == 2)
    }
}
