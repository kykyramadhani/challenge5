//
//  OnboardingView.swift
//  GetCooking
//
//  The first-launch introduction, starring Smoove. Works like the tutorial:
//  each page types its line out, and a tap either finishes the current line
//  (if it is still typing) or moves on to the next page. The last page's tap
//  ends onboarding.
//
//  Shown once, gated by @AppStorage in ContentView, so it only appears on a
//  fresh install.
//

import SwiftUI

struct OnboardingView: View {
    /// Called after the final page is dismissed.
    var onFinished: () -> Void

    // MARK: - Pages

    private struct Page {
        let image: String   // asset name for Smoove's pose
        let text: String
    }

    private let pages: [Page] = [
        Page(
            image: "Happy",
            text: "Hi, I'm Smoove! I'll be your buddy throughout the game. Let's stay active together!"
        ),
        Page(
            image: "Excited",
            text: "Here, you'll find fun interactive games that keep you moving! Get ready to move!"
        ),
    ]

    // MARK: - State

    @State private var pageIndex = 0
    @State private var typedText = ""          // characters revealed so far
    @State private var isTyping = false        // line still being typed out
    @State private var isTalking = false       // drives the bubble bob
    @State private var typingTask: Task<Void, Never>?

    /// Seconds between typed characters.
    private let characterDelay: Duration = .milliseconds(35)

    private var page: Page { pages[pageIndex] }

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                Image("OnboardingBackground")
                    .resizable()
                    .scaledToFit()
                    .frame(width: w, height: h)

                // Smoove, anchored to the bottom of the screen.
                Image(page.image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: h * 0.62)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    // A soft cross-fade when the pose changes between pages.
                    .id(page.image)
                    .transition(.opacity)

                // Speech bubble + hint, tucked into the top-right.
                VStack(alignment: .trailing, spacing: 10) {
                    speechBubble(maxWidth: min(w * 0.5, 360))
                        .scaleEffect(isTalking ? 1.025 : 1.0, anchor: .bottomLeading)
                        .offset(y: isTalking ? -3 : 0)
                        .animation(
                            isTalking
                                ? .easeInOut(duration: 0.55)
                                : .easeInOut(duration: 0.2),
                            value: isTalking
                        )

                    Text("Tap anywhere to continue →")
                        .font(.atkinson(size: 28, weight: .regular))
                        .foregroundStyle(.black.opacity(0.45))
                        .padding(.trailing, 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, h * 0.14)
                .padding(.trailing, w * 0.08)
            }
            .frame(width: w, height: h)
            .contentShape(Rectangle())
            .onTapGesture { advance() }
        }
        .ignoresSafeArea()
        .onAppear {
            if typedText.isEmpty { beginTyping() }
        }
        .onDisappear { typingTask?.cancel() }
        .designScaled()
    }

    // MARK: - Speech bubble

    private func speechBubble(maxWidth: CGFloat) -> some View {
        // The full line is laid out invisibly so the bubble is sized once, up
        // front — the typed text then fills in without the bubble resizing (and
        // jumping) on every character.
        ZStack {
            Text(page.text).opacity(0)
            Text(typedText)
        }
        .font(.atkinson(size: 22, weight: .bold))
        .foregroundStyle(.black)
        .multilineTextAlignment(.center)
        .frame(width: maxWidth)
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 22 + Self.tailHeight)
        .background(
            SpeechBubble(tailHeight: Self.tailHeight)
                .fill(.white)
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
        )
    }

    private static let tailHeight: CGFloat = 18

    // MARK: - Background (placeholder)

    /// A warm room-ish backdrop. Swap this whole property for
    /// `Image("Room").resizable().scaledToFill()` once a room asset exists.
    private var background: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        Color(red: 0.80, green: 0.64, blue: 0.46),
                        Color(red: 0.72, green: 0.55, blue: 0.38),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Color(red: 0.44, green: 0.29, blue: 0.18)
                    .frame(height: proxy.size.height * 0.30)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Typing

    private func beginTyping() {
        typingTask?.cancel()
        typedText = ""
        isTyping = true
        isTalking = true

        let full = page.text
        typingTask = Task { @MainActor in
            for character in full {
                if Task.isCancelled { return }
                typedText.append(character)
                try? await Task.sleep(for: characterDelay)
            }
            finishTyping()
        }
    }

    /// Reveals the whole line at once and stops the talking bob.
    private func finishTyping() {
        typingTask?.cancel()
        typedText = page.text
        isTyping = false
        isTalking = false
    }

    // MARK: - Tap handling

    private func advance() {
        if isTyping {
            // First tap during typing: snap to the full line.
            finishTyping()
            return
        }

        if pageIndex < pages.count - 1 {
            withAnimation(.easeInOut(duration: 0.25)) { pageIndex += 1 }
            beginTyping()
        } else {
            onFinished()
        }
    }
}

// MARK: - Bubble shape

/// A rounded speech bubble with a downward tail near its lower-left, pointing
/// toward Smoove.
private struct SpeechBubble: Shape {
    var cornerRadius: CGFloat = 26
    var tailHeight: CGFloat = 18
    var tailWidth: CGFloat = 26
    /// Where the tail sits along the bottom edge, as a fraction from the left.
    var tailPosition: CGFloat = 0.24

    func path(in rect: CGRect) -> Path {
        let body = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: rect.height - tailHeight
        )

        var path = Path(roundedRect: body, cornerRadius: cornerRadius)

        let tailX = body.minX + body.width * tailPosition
        var tail = Path()
        tail.move(to: CGPoint(x: tailX, y: body.maxY - 2))
        tail.addLine(to: CGPoint(x: tailX + tailWidth, y: body.maxY - 2))
        tail.addLine(to: CGPoint(x: tailX + tailWidth * 0.15, y: rect.maxY))
        tail.closeSubpath()
        path.addPath(tail)

        return path
    }
}

#Preview {
    OnboardingView(onFinished: {})
}
