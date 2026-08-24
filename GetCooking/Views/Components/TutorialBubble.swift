//
//  TutorialBubble.swift
//  GetCooking
//
//  The tutorial's dialogue bubble: the designer's popover artwork with the
//  line typed into it.
//
//  The artwork is used at 1× — its body is exactly the 506×200 the benchmark
//  pages are laid out around — and the copy is drawn on top in SwiftUI so it
//  can be localized. Everything is expressed on the 1366×1024 design canvas
//  and multiplied by `scale`, so a bubble lands on the same part of the
//  picture whatever size the page is rendered at.
//

import SwiftUI

struct TutorialBubble: View {
    /// The whole line, already localized. Always laid out in full — see
    /// `body` — even while only part of it is visible.
    let text: String

    /// How many characters of `text` to show. The typewriter's clock lives in
    /// `TutorialView`, which also owns the tap that skips to the end, so the
    /// two can never disagree about whether the line has finished.
    let revealed: Int

    /// Pages 1 and 11 have the character speaking, and the design gives those
    /// bubbles a tail. The rest are plain, so the tail is cropped away rather
    /// than pointing at nothing.
    let showsTail: Bool

    /// Points-per-design-point.
    let scale: CGFloat

    // MARK: - The artwork, measured

    /// Popover.png's own size.
    static let assetSize = CGSize(width: 706, height: 413)

    /// Where the bubble body sits inside that asset — the rest is drop shadow,
    /// plus the tail hanging below.
    static let bodyOrigin = CGPoint(x: 100, y: 90)
    static let bodySize = CGSize(width: 506, height: 200)

    /// How far below the body the tail reaches.
    static let tailDrop: CGFloat = 13

    /// Inset from the body's edges to the text.
    static let textInset = CGSize(width: 30, height: 22)

    static let fontSize: CGFloat = 26
    static let lineSpacing: CGFloat = 7

    /// The body's width, which is what page anchors are measured against.
    static var width: CGFloat { bodySize.width }

    /// How much of the asset to keep. Without a tail the artwork is cut off at
    /// the bottom of the body; with one it runs on to include the tail.
    private var visibleHeight: CGFloat {
        showsTail
            ? Self.bodyOrigin.y + Self.bodySize.height + Self.tailDrop
            : Self.bodyOrigin.y + Self.bodySize.height
    }

    var body: some View {
        Image("TutorialPopover")
            .resizable()
            .interpolation(.high)
            .frame(width: Self.assetSize.width * scale,
                   height: Self.assetSize.height * scale)
            // Cropped from the top-left, so the body keeps its position inside
            // the frame and only the unused shadow (and tail) is trimmed.
            .frame(
                width: Self.assetSize.width * scale,
                height: visibleHeight * scale,
                alignment: .top
            )
            .clipped()
            .overlay(alignment: .topLeading) { caption }
            // The whole thing is positioned by the *body's* top-left corner,
            // not the asset's, so the shadow around it never shifts the bubble
            // off the spot the design puts it on.
            .padding(.leading, -Self.bodyOrigin.x * scale)
            .padding(.top, -Self.bodyOrigin.y * scale)
    }

    /// The line, centred in the body.
    private var caption: some View {
        label(String(text.prefix(max(0, revealed))))
            // The *full* line, hidden, holds the layout still: without it the
            // text would re-centre itself on every character as it types in.
            .background(label(text).hidden())
            .frame(
                width: Self.bodySize.width * scale,
                height: Self.bodySize.height * scale
            )
            .offset(x: Self.bodyOrigin.x * scale, y: Self.bodyOrigin.y * scale)
    }

    private func label(_ string: String) -> some View {
        Text(string)
            .font(.system(size: Self.fontSize * scale, weight: .bold))
            .multilineTextAlignment(.center)
            .lineSpacing(Self.lineSpacing * scale)
            .foregroundStyle(.black)
            // A longer translation shrinks to fit rather than spilling out of
            // artwork that cannot grow with it.
            .minimumScaleFactor(0.55)
            .frame(
                width: (Self.bodySize.width - Self.textInset.width * 2) * scale,
                height: (Self.bodySize.height - Self.textInset.height * 2) * scale
            )
    }
}

#Preview {
    ZStack {
        Color(red: 0.78, green: 0.60, blue: 0.42)
        VStack(alignment: .leading, spacing: 60) {
            TutorialBubble(
                text: "Hi! In this game you'll be taking role as a chef at a new restaurant! I'll show you how to play. Let's get moving!",
                revealed: 999, showsTail: true, scale: 1
            )
            TutorialBubble(
                text: "The needed ingredients will show up here!",
                revealed: 999, showsTail: false, scale: 1
            )
        }
    }
}
