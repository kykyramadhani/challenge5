//
//  TutorialLayoutTests.swift
//  PlayFeatTests
//
//  Split out of GetCookingTests.swift (created by Kyky on 11/08/26).
//

import Testing
import Foundation
import CoreGraphics
import SwiftUI
import UIKit
@testable import PlayFeat

/// Laying the tutorial artwork out, and placing the bubbles on it.
///
/// The Skip button is a real SwiftUI button now rather than a hit area
/// measured over painted-on artwork, so there is no hotspot left to pin down.
@MainActor
struct TutorialLayoutTests {

    /// Landscape iPad — wider than the 4:3 artwork.
    private let landscape = CGSize(width: 1194, height: 834)

    /// Portrait, where the same page has to letterbox the other way.
    private let portrait = CGSize(width: 834, height: 1194)

    /// Fitted, so the whole page is always visible — nothing is cropped away,
    /// least of all the Skip button sitting near the edge.
    @Test func thePageFitsInsideTheScreen() {
        for screen in [landscape, portrait] {
            let page = TutorialView.pageRect(in: screen)

            #expect(page.width <= screen.width + 0.001)
            #expect(page.height <= screen.height + 0.001)
        }
    }

    /// Centred, and keeping the artwork's own 4:3 shape.
    @Test func thePageIsCentredAndKeepsItsAspect() {
        let page = TutorialView.pageRect(in: landscape)

        #expect(abs(page.midX - landscape.width / 2) < 0.001)
        #expect(abs(page.midY - landscape.height / 2) < 0.001)

        let drawn = TutorialView.pageSize.width / TutorialView.pageSize.height
        #expect(abs(page.width / page.height - drawn) < 0.001)
    }

    /// A screen already at 4:3 wastes nothing.
    @Test func aMatchingScreenIsFilledCompletely() {
        let exact = CGSize(width: 1366, height: 1024)
        let page = TutorialView.pageRect(in: exact)

        #expect(abs(page.width - exact.width) < 0.001)
        #expect(abs(page.height - exact.height) < 0.001)
    }

    /// Every page has to resolve to something drawable, or the walkthrough
    /// shows a blank screen the player can only tap past.
    @Test func everyPageHasArtwork() {
        for page in TutorialPage.all {
            switch page.backdrop {
            case let .still(name):
                #expect(UIImage(named: name) != nil, "missing image \(name)")
            case let .clip(name):
                #expect(
                    Bundle.main.url(forResource: name, withExtension: "mov") != nil,
                    "missing clip \(name)"
                )
            }
        }
    }

    /// Copy is resolved through the localization tables, so a page that has a
    /// line must still have one after that round trip — an empty result means
    /// the bubble renders as a blank box.
    @Test func everyCaptionResolvesToText() {
        for page in TutorialPage.all where page.message != nil {
            #expect(page.localizedMessage?.isEmpty == false,
                    "page \(page.id) resolved to nothing")
        }
    }

    /// The anchors are hand-placed off the benchmark artwork, so this is the
    /// check that one of them was not mistyped: the bubble is a fixed-size
    /// piece of art, so it has to start on the page and still fit whole.
    @Test func everyBubbleAnchorKeepsTheBubbleOnThePage() {
        let widthShare = TutorialBubble.bodySize.width / TutorialView.pageSize.width
        let heightShare = TutorialBubble.bodySize.height / TutorialView.pageSize.height

        for page in TutorialPage.all where page.message != nil {
            let anchor = page.bubbleAnchor
            #expect(anchor.x >= 0 && anchor.y >= 0, "page \(page.id) starts off-page")
            #expect(anchor.x + widthShare <= 1.001,
                    "page \(page.id) runs off the right edge")
            #expect(anchor.y + heightShare <= 1.001,
                    "page \(page.id) runs off the bottom")
        }
    }

    /// The popover artwork is used at 1×, and the page anchors are measured
    /// against the body inside it. If the asset is ever re-exported at a
    /// different size these numbers stop describing it, and every bubble
    /// silently lands in the wrong place.
    @Test func theBubbleArtworkMatchesItsMeasurements() throws {
        let art = try #require(UIImage(named: "TutorialPopover"))

        #expect(art.size == TutorialBubble.assetSize)
        #expect(TutorialBubble.bodyOrigin.x + TutorialBubble.bodySize.width
                <= TutorialBubble.assetSize.width)
        #expect(TutorialBubble.bodyOrigin.y + TutorialBubble.bodySize.height
                + TutorialBubble.tailDrop <= TutorialBubble.assetSize.height)
    }

    /// A zero-sized container must not divide by zero.
    @Test func anEmptyScreenIsHandled() {
        #expect(TutorialView.pageRect(in: .zero) == .zero)
    }
}
