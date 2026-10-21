//
//  IngredientCardPickerTests.swift
//  PlayFeatTests
//
//  Two cards for the active order, one for an order behind it, and no
//  pointless duplicates — checked over many deals, since picks are random.
//

import Testing
@testable import PlayFeat

@MainActor
struct IngredientCardPickerTests {
    private let current: [KitchenIngredient] = [.glowingMushroom, .coralLettuce, .bubbleTuber, .starJelly]
    private let upcoming: [KitchenIngredient] = [.bubbleTuber, .bubbleTuber, .coralLettuce]

    @Test func dealGivesTwoCardsForTheActiveOrderAndOneForLater() {
        for _ in 0..<200 {
            let cards = IngredientCardPicker.deal(current: [.glowingMushroom, .starJelly], upcoming: upcoming)
            #expect(Set(cards.prefix(2)) == [.glowingMushroom, .starJelly])
            #expect(upcoming.contains(cards[2]))
        }
    }

    @Test func replacementTopsUpTheActiveOrderFirst() {
        for _ in 0..<200 {
            // Neither card left on the table helps the active order.
            let pick = IngredientCardPicker.replacement(among: [.coralLettuce, .bubbleTuber],
                                                        current: [.glowingMushroom, .starJelly],
                                                        upcoming: upcoming)
            #expect(pick == .glowingMushroom || pick == .starJelly)
        }
    }

    @Test func replacementLooksAheadOnceTheActiveOrderHasTwoCards() {
        for _ in 0..<200 {
            let pick = IngredientCardPicker.replacement(among: [.glowingMushroom, .starJelly],
                                                        current: current, upcoming: upcoming)
            #expect(pick == .bubbleTuber || pick == .coralLettuce)
        }
    }

    /// Even an order of two coral lettuces gets one coral card, not two.
    @Test func neverDealsADuplicate() {
        for _ in 0..<200 {
            let pick = IngredientCardPicker.replacement(among: [.coralLettuce, .starJelly],
                                                        current: [.coralLettuce, .coralLettuce],
                                                        upcoming: [.coralLettuce])
            #expect(pick != .coralLettuce && pick != .starJelly)

            let cards = IngredientCardPicker.deal(current: [.coralLettuce, .coralLettuce], upcoming: [.coralLettuce])
            #expect(Set(cards).count == 3)
        }
    }
}
