//
//  TutorialView.swift
//  GetCooking
//
//  The illustrated walkthrough shown between the main menu and the seat
//  check. Each page is a full-screen picture the designer numbered; tapping
//  anywhere moves on, and Skip jumps straight to the seat check.
//
//  The Skip button is *painted into the artwork*, so there is no button here
//  to style — only an invisible hit area laid exactly over where it is drawn.
//  That keeps the pages pixel-identical to the design at the cost of one
//  measured rectangle, which is why `pageRect` exists.
//

import SwiftUI

struct TutorialView: View {
    /// Called when the last page is passed, or Skip is tapped.
    var onFinished: () -> Void

    @State private var step = 1

    // MARK: - Pages

    /// How many pages there are. Add one by dropping `Tutorial11` into the
    /// asset catalog and raising this.
    static let pageCount = 10

    /// Pages authored as short clips rather than stills.
    static let animatedPages: Set<Int> = [5, 7]

    /// The same pages in a stable order, since `ForEach` needs one and a Set
    /// has none.
    static let animatedPagesInOrder = animatedPages.sorted()

    /// The size every page was drawn at. All ten share it, stills and clips
    /// alike, so one layout calculation serves the lot.
    static let pageSize = CGSize(width: 1366, height: 1024)

    /// Where the Skip button sits inside the artwork, as a fraction of the
    /// page. Measured off the source files, and padded a little so it is
    /// comfortable to hit.
    static let skipHotspot = CGRect(x: 0.02, y: 0.83, width: 0.21, height: 0.11)

    // MARK: - Layout

    /// Where the page lands inside `container` when scaled to fit.
    ///
    /// The artwork is 4:3 and the app rotates freely, so the page rarely fills
    /// the screen exactly. Everything positional is measured against this rect
    /// rather than the screen, which is what keeps the Skip hotspot on top of
    /// the drawn button whatever shape the screen is.
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

    /// The Skip hit area in screen coordinates.
    static func skipRect(in container: CGSize) -> CGRect {
        let page = pageRect(in: container)

        return CGRect(
            x: page.minX + skipHotspot.minX * page.width,
            y: page.minY + skipHotspot.minY * page.height,
            width: skipHotspot.width * page.width,
            height: skipHotspot.height * page.height
        )
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let page = Self.pageRect(in: proxy.size)
            let skip = Self.skipRect(in: proxy.size)

            ZStack {
                // Letterbox behind the page, since the art is 4:3 and the
                // screen usually is not.
                Color.black

                content
                    .frame(width: page.width, height: page.height)
                    .position(x: page.midX, y: page.midY)

                // "Tap anywhere to continue", exactly as the pages promise.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { advance() }

                // Sits above the tap-anywhere layer, so it wins the tap.
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: skip.width, height: skip.height)
                    .position(x: skip.midX, y: skip.midY)
                    .onTapGesture { onFinished() }
            }
        }
        .ignoresSafeArea()
    }

    /// The page itself.
    ///
    /// Stills are swapped in and out freely — an `Image` draws the moment it
    /// appears. The clips are *not*: every animated page stays mounted for the
    /// whole tutorial and is merely revealed by opacity, because building an
    /// `AVPlayer` at the moment its page arrives leaves the layer blank while
    /// the file loads, which shows up as a black flash on the page turn.
    private var content: some View {
        ZStack {
            if !Self.animatedPages.contains(step) {
                Image("Tutorial\(step)")
                    .resizable()
                    .scaledToFit()
            }

            ForEach(Self.animatedPagesInOrder, id: \.self) { page in
                LoopingVideoView(
                    resource: "Tutorial\(page)",
                    isActive: step == page
                )
                .opacity(step == page ? 1 : 0)
            }
        }
    }

    private func advance() {
        if step < Self.pageCount {
            step += 1
        } else {
            onFinished()
        }
    }
}

#Preview {
    TutorialView {}
}
