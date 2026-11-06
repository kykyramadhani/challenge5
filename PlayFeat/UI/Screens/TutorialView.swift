//
//  TutorialView.swift
//  GetCooking
//
//  The walkthrough shown between the main menu and the seat check.
//
//  Only the *artwork* comes from the design files — the bubble's copy, the
//  "tap to continue" prompt and the Skip / Start Game buttons are drawn here,
//  so every word can be localized without re-exporting a single page.
//
//  Each line types itself in, and a tap always turns the page — typing or not.
//  One page is the exception: the wordless pinch clip plays once and hands
//  over by itself, so there is nothing there to tap past.
//

import SwiftUI

struct TutorialView: View {
    /// Called when the last page is passed, or Skip is tapped.
    var onFinished: () -> Void

    /// Which page to open on. Only ever moved off zero by previews.
    var startingPage = 0

    @State private var index: Int

    /// How many characters of the current line are on screen.
    ///
    /// Starts *above* any possible length rather than at zero, so a context
    /// that never runs the typing task — a preview, a snapshot — shows the
    /// finished line instead of an empty bubble. The task sets it to zero
    /// itself before counting up.
    @State private var revealed = Int.max

    init(startingPage: Int = 0, onFinished: @escaping () -> Void) {
        self.startingPage = startingPage
        self.onFinished = onFinished
        _index = State(initialValue: startingPage)
    }

    private var page: TutorialPage { TutorialPage.all[index] }
    private var line: String { page.localizedMessage ?? "" }
    private var isTyping: Bool { revealed < line.count }
    private var isLastPage: Bool { index == TutorialPage.all.count - 1 }

    // MARK: - Design canvas

    /// The size every page was drawn at — stills and clips alike, so one
    /// layout calculation serves the lot.
    static let pageSize = CGSize(width: 1366, height: 1024)

    /// Seconds per character.
    private static let characterInterval: TimeInterval = 0.028

    /// The buttons, measured off the artwork they replace. Start Game is both
    /// wider and drawn into page 11's background, so this rect has to cover
    /// the painted one exactly.
    private static let skipRect = CGRect(x: 47, y: 863, width: 245, height: 106)
    private static let startRect = CGRect(x: 35, y: 866, width: 401, height: 106)

    /// The "tap to continue" prompt, sampled from the benchmark pages: one
    /// mid-grey that reads on both the light wall and the dark gameplay shots.
    private static let promptGrey = Color(white: 0.5)

    /// Where the page lands inside `container` when scaled to fit.
    ///
    /// The artwork is 4:3 and the app rotates freely, so the page rarely fills
    /// the screen exactly. Everything positional is measured against this rect
    /// rather than the screen, which keeps the bubbles sitting on the part of
    /// the picture they are pointing at whatever shape the screen is.
    static func pageRect(in container: CGSize) -> CGRect {
        guard container.width > 0, container.height > 0 else { return .zero }

        let scale = min(
            container.width / pageSize.width,
            container.height / pageSize.height
        )
        let size = CGSize(
            width: pageSize.width * scale,
            height: pageSize.height * scale
        )

        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let rect = Self.pageRect(in: proxy.size)
            let scale = rect.width / Self.pageSize.width

            ZStack {
                // Letterbox behind the page, since the art is 4:3 and the
                // screen usually is not.
                Color.black

                backdrop
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)

                // Tap anywhere to turn the page.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { advance() }

                bubbleLayer(in: rect, scale: scale)

                // Above the tap-anywhere layer, so it wins the tap.
                pageButton(in: rect, scale: scale)
            }
        }
        .ignoresSafeArea()
        // Keyed on the page, so turning it restarts the typewriter from zero.
        .task(id: index) {
            revealed = 0
            guard !line.isEmpty else { return }

            for step in 1...line.count {
                do {
                    try await Task.sleep(for: .seconds(Self.characterInterval))
                } catch {
                    return // page turned mid-line
                }
                revealed = step
            }
        }
    }

    /// The picture behind the page.
    ///
    /// Stills are swapped in and out freely — an `Image` draws the moment it
    /// appears. The clips are *not*: every clip stays mounted for the whole
    /// tutorial and is merely revealed by opacity, because building an
    /// `AVPlayer` at the moment its page arrives leaves the layer blank while
    /// the file loads, which shows up as a black flash on the page turn.
    private var backdrop: some View {
        ZStack {
            if case let .still(name) = page.backdrop {
                Image(name)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            }

            ForEach(TutorialPage.clipNames, id: \.self) { name in
                let showing = isShowing(clip: name)

                LoopingVideoView(
                    resource: name,
                    fileExtension: "mov",
                    isActive: showing,
                    playsOnce: playsOnce(clip: name),
                    onFinished: showing ? { advance() } : nil
                )
                .opacity(showing ? 1 : 0)
            }
        }
    }

    private func isShowing(clip name: String) -> Bool {
        if case let .clip(current) = page.backdrop { return current == name }
        return false
    }

    /// Whether this clip is the one that plays through once rather than
    /// looping. Looked up by name because the clips are all mounted at once
    /// and only one of them is the current page's.
    private func playsOnce(clip name: String) -> Bool {
        TutorialPage.all.contains {
            if case let .clip(current) = $0.backdrop {
                return current == name && $0.advancesWhenClipEnds
            }
            return false
        }
    }

    /// The bubble and the prompt under it, pinned to the page's own geometry.
    @ViewBuilder
    private func bubbleLayer(in rect: CGRect, scale: CGFloat) -> some View {
        if !line.isEmpty {
            overlaid(on: rect, at: page.bubbleAnchor) {
                VStack(alignment: .leading, spacing: 8 * scale) {
                    TutorialBubble(
                        text: line,
                        revealed: revealed,
                        showsTail: page.showsTail,
                        scale: scale
                    )

                    // Held back until the line has finished, so it reads as
                    // "you have read it, now move on" rather than hurrying the
                    // player past a sentence still being typed.
                    Text("Tap anywhere to continue →")
                        .font(.atkinson(size: 25 * scale))
                        .foregroundStyle(Self.promptGrey)
                        .padding(.leading, 12 * scale)
                        .opacity(isTyping ? 0 : 1)
                        .animation(.easeIn(duration: 0.2), value: isTyping)
                }
                .allowsHitTesting(false)
            }
        }
    }

    /// Skip on every page but the last, which offers Start Game instead.
    private func pageButton(in rect: CGRect, scale: CGFloat) -> some View {
        let box = isLastPage ? Self.startRect : Self.skipRect

        return overlaid(on: rect, at: CGPoint(x: box.minX / Self.pageSize.width,
                                              y: box.minY / Self.pageSize.height)) {
            Button(action: onFinished) {
                HStack(spacing: 12 * scale) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 30 * scale, weight: .black))
                    Text(isLastPage ? "Start Game" : "Skip")
                        .font(.atkinson(size: 44 * scale, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .foregroundStyle(Color.appPrimary)
                // Sized to the measured artwork rather than to its own text:
                // on the last page this button is drawn *over* a Start Game
                // painted into the background, and has to cover it.
                .frame(width: box.width * scale, height: box.height * scale)
                .background(Capsule().fill(.black))
            }
            .buttonStyle(.plain)
        }
    }

    /// Places `content` with its **top-leading corner** on `anchor`, given as
    /// a fraction of the page.
    ///
    /// A page-sized, top-leading stack rather than `.position`, which works off
    /// a view's centre: these anchors describe a corner, and the bubble's
    /// height is not known in advance — it changes with the length of the
    /// translated copy.
    private func overlaid<Content: View>(
        on rect: CGRect,
        at anchor: CGPoint,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            content()
                .offset(x: anchor.x * rect.width, y: anchor.y * rect.height)
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
    }

    /// Turns the page. A tap does this whether or not the line has finished
    /// typing — there is no tap-to-reveal step.
    private func advance() {
        if index < TutorialPage.all.count - 1 {
            index += 1
        } else {
            onFinished()
        }
    }
}

#Preview {
    TutorialView {}
}
