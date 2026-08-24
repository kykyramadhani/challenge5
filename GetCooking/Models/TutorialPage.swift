//
//  TutorialPage.swift
//  GetCooking
//
//  The tutorial's script: one entry per page, with the artwork behind it and
//  the line the character says over it.
//
//  Copy lives here as `String.LocalizationValue`, so every line is picked up
//  by Xcode's string extraction and can be translated without touching the
//  artwork — which is the whole reason the bubbles are drawn in SwiftUI now
//  rather than baked into the page images.
//
//  Positions are given on the 1366×1024 design canvas the artwork was drawn
//  at, as fractions of it. `TutorialView` scales them to whatever the page
//  actually renders at.
//

import CoreGraphics
import Foundation

struct TutorialPage: Identifiable {

    /// What fills the page behind the bubble.
    enum Backdrop {
        /// Asset-catalog image name.
        case still(String)
        /// Bundled clip name, played on a loop.
        case clip(String)
    }

    let id: String
    let backdrop: Backdrop

    /// The character's line. Nil on pages that are pure demonstration — the
    /// short pinch clip has no caption in the design, it just plays.
    let message: String.LocalizationValue?

    /// Top-leading corner of the bubble, as a fraction of the page. The bubble
    /// grows *downward* from here, so a longer translation runs into the page
    /// instead of drifting off its anchor.
    let bubbleAnchor: CGPoint

    /// Whether the bubble keeps the popover's tail. Only the two pages where
    /// the character is on screen and speaking have one; elsewhere the design
    /// uses the same bubble with a plain bottom edge.
    let showsTail: Bool

    init(
        id: String,
        backdrop: Backdrop,
        message: String.LocalizationValue? = nil,
        bubbleAnchor: CGPoint = .zero,
        showsTail: Bool = false
    ) {
        self.id = id
        self.backdrop = backdrop
        self.message = message
        self.bubbleAnchor = bubbleAnchor
        self.showsTail = showsTail
    }

    /// The line, resolved for the current locale.
    var localizedMessage: String? {
        message.map { String(localized: $0) }
    }

    // MARK: - The script

    static let all: [TutorialPage] = [
        TutorialPage(
            id: "1",
            backdrop: .still("TutorialBG1"),
            message: "Hi! In this game you'll be taking role as a chef at a new restaurant! I'll show you how to play. Let's get moving!",
            bubbleAnchor: CGPoint(x: 0.5198, y: 0.2314),
            showsTail: true
        ),
        TutorialPage(
            id: "2",
            backdrop: .clip("TutorialClip2"),
            message: "Place your device where the camera can clearly see your upper body.",
            bubbleAnchor: CGPoint(x: 0.0351, y: 0.1152)
        ),
        TutorialPage(
            id: "3",
            backdrop: .clip("TutorialClip3"),
            message: "Get into position! Raise your hand and make sure it fit inside the frame.",
            bubbleAnchor: CGPoint(x: 0.0930, y: 0.5781)
        ),
        // No caption in the design — the clip is a beat on its own before the
        // board is explained piece by piece.
        TutorialPage(
            id: "4a",
            backdrop: .clip("TutorialClip4a")
        ),
        TutorialPage(
            id: "4b",
            backdrop: .still("TutorialBG4b"),
            message: "Your order ingredients will appear here! Watch the border! It turns red as time runs out!",
            bubbleAnchor: CGPoint(x: 0.2884, y: 0.1738)
        ),
        TutorialPage(
            id: "5",
            backdrop: .still("TutorialBG5"),
            message: "Here, you can see how many plates you successfully delivered on time.",
            bubbleAnchor: CGPoint(x: 0.0776, y: 0.1650)
        ),
        TutorialPage(
            id: "6",
            backdrop: .still("TutorialBG6"),
            message: "You have 3 hearts!\nRun out of time? You'll lose a heart!",
            bubbleAnchor: CGPoint(x: 0.5681, y: 0.1367)
        ),
        TutorialPage(
            id: "7",
            backdrop: .still("TutorialBG7"),
            message: "The needed ingredients will show up here!",
            bubbleAnchor: CGPoint(x: 0.3675, y: 0.3643)
        ),
        TutorialPage(
            id: "8",
            backdrop: .clip("TutorialClip8"),
            message: "Pinch to grab!\nThen drag the ingredient to the plate.",
            bubbleAnchor: CGPoint(x: 0.3148, y: 0.4668)
        ),
        TutorialPage(
            id: "9",
            backdrop: .clip("TutorialClip9"),
            message: "When the order is ready, a bell and tray will appear on either side. Pinch the dish and drag it to the tray!",
            bubbleAnchor: CGPoint(x: 0.3148, y: 0.4746)
        ),
        TutorialPage(
            id: "10",
            backdrop: .clip("TutorialClip10"),
            message: "Oops! Wrong ingredient? Hold your open hand over the reset button for 2 seconds to clear the plate.",
            bubbleAnchor: CGPoint(x: 0.0300, y: 0.5762)
        ),
        TutorialPage(
            id: "11",
            backdrop: .still("TutorialBG11"),
            message: "All set! Delivered lots of dishes and stay active!",
            bubbleAnchor: CGPoint(x: 0.5198, y: 0.2314),
            showsTail: true
        )
    ]

    /// The clips, in a stable order. Every one stays mounted for the whole
    /// tutorial (see `LoopingVideoView`), and `ForEach` needs an order.
    static let clipNames: [String] = all.compactMap {
        if case let .clip(name) = $0.backdrop { return name }
        return nil
    }
}
