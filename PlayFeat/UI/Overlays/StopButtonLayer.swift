//
//  StopButtonLayer.swift
//  PlayFeat
//
//  The hidden way out of a run. The board is played with hands, not touch, so
//  a permanent button would only sit over the camera feed: instead a tap
//  anywhere reveals a Stop button, which hides itself again after a while.
//

import SwiftUI

struct StopButtonLayer: View {
    let onStop: () -> Void

    @State private var isRevealed = false

    /// Long enough to reach the button, short enough that a forgotten tap
    /// doesn't leave it sitting over the feed.
    private static let autoHideDelay: Duration = .seconds(5)

    var body: some View {
        ZStack {
            // Full-screen tap catcher. A tap toggles the button; with the
            // button showing, a tap that misses it lands here and hides it.
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture { setRevealed(!isRevealed) }

            if isRevealed {
                stopButton
                    .transition(.opacity)
            }
        }
        // Each fresh reveal restarts the timer, through the id.
        .task(id: isRevealed) {
            guard isRevealed else { return }
            do {
                try await Task.sleep(for: Self.autoHideDelay)
            } catch {
                return
            }
            setRevealed(false)
        }
    }

    /// Bottom-left, clear of the HUD row across the top.
    private var stopButton: some View {
        VStack {
            Spacer()
            HStack {
                ButtonComponent(
                    name: "Stop",
                    icon: "xmark",
                    action: stop,
                    buttonStyle: .primary
                )
                .padding(40)

                Spacer()
            }
        }
    }

    private func stop() {
        isRevealed = false
        onStop()
    }

    private func setRevealed(_ revealed: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            isRevealed = revealed
        }
    }
}

#Preview {
    StopButtonLayer(onStop: {})
        .environment(AudioManager())
}
