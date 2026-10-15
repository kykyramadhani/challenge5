//
//  ChefBubblePickerTests.swift
//  PlayFeatTests
//
//  Bubbles still wanted stay put, unwanted ones go, empty slots fill in
//  order of urgency, and nothing is ever supplied twice.
//

import Testing
@testable import PlayFeat

struct ChefBubblePickerTests {
    @Test func fillsEmptySlotsMostUrgentFirst() {
        let refilled = ChefBubblePicker.refill([nil, nil, nil], wanted: [.tentacle, .coralLettuce])
        #expect(refilled == [.tentacle, .coralLettuce, nil])
    }

    @Test func keepsWantedBubblesWhereTheyAre() {
        let refilled = ChefBubblePicker.refill([nil, .coralLettuce, nil], wanted: [.tentacle, .coralLettuce])
        #expect(refilled == [.tentacle, .coralLettuce, nil])
    }

    @Test func clearsBubblesNothingWantsAnyMore() {
        let refilled = ChefBubblePicker.refill([.bubbleTuber, .tentacle], wanted: [.tentacle])
        #expect(refilled == [nil, .tentacle])
    }

    /// Two lettuces wanted, three floating: one has to go.
    @Test func neverMoreOfAKindThanWanted() {
        let refilled = ChefBubblePicker.refill([.coralLettuce, .coralLettuce, .coralLettuce],
                                               wanted: [.coralLettuce, .coralLettuce])
        #expect(refilled == [.coralLettuce, .coralLettuce, nil])
    }
}
