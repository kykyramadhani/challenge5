//
//  BubblePickerTests.swift
//  PlayFeatTests
//
//  Bubbles still wanted stay put, unwanted ones go, empty slots fill in
//  order of urgency, and nothing is ever supplied twice.
//

import Testing
@testable import PlayFeat

struct BubblePickerTests {
    @Test func fillsEmptySlotsMostUrgentFirst() {
        let refilled = BubblePicker.refill([nil, nil, nil], wanted: [.tentacle, .coralLettuce])
        #expect(refilled == [.tentacle, .coralLettuce, nil])
    }

    @Test func keepsWantedBubblesWhereTheyAre() {
        let refilled = BubblePicker.refill([nil, .coralLettuce, nil], wanted: [.tentacle, .coralLettuce])
        #expect(refilled == [.tentacle, .coralLettuce, nil])
    }

    @Test func clearsBubblesNothingWantsAnyMore() {
        let refilled = BubblePicker.refill([.bubbleTuber, .tentacle], wanted: [.tentacle])
        #expect(refilled == [nil, .tentacle])
    }

    /// Two lettuces wanted, three floating: one has to go.
    @Test func neverMoreOfAKindThanWanted() {
        let refilled = BubblePicker.refill([.coralLettuce, .coralLettuce, .coralLettuce],
                                               wanted: [.coralLettuce, .coralLettuce])
        #expect(refilled == [.coralLettuce, .coralLettuce, nil])
    }

    /// Never more than `limit` floating, however much is wanted.
    @Test func neverMoreThanTheLimit() {
        let refilled = BubblePicker.refill([.tentacle, nil, nil, nil, nil],
                                           wanted: [.tentacle, .coralLettuce, .bubbleTuber, .starJelly], limit: 3)
        #expect(refilled == [.tentacle, .coralLettuce, .bubbleTuber, nil, nil])
    }
}
