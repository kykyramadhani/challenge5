//
//  GetReadyOverlay.swift
//  GetCooking
//
//  The 3-2-1-GO! between passing the seat check and the first recipe landing.
//
//  Deliberately shown over a live board — camera, plate and HUD all visible
//  behind it — so the player can settle their hands before anything is asked
//  of them.
//

import SwiftUI

struct GetReadyOverlay: View {
    /// Seconds left: 3, 2, 1, then 0 for the "GO!" beat. The overlay is gone
    /// by the time it goes negative.
    let count: Int

    var body: some View {
        VStack(spacing: 0) {
            // Only on the first beat. By the second the player has read it,
            // and leaving it up just crowds the numbers.
            Text("GET READY!")
                .font(.system(size: 56, weight: .black))
                .opacity(count == 3 ? 1 : 0)
                .padding(.top, 140)

            Spacer()

            // "GO!" rather than a fourth number, so the beat play actually
            // starts on is unmistakable. Sized down a little because three
            // glyphs at 160pt overflow a narrow screen.
            Text(count > 0 ? "\(count)" : "GO!")
                .font(.system(size: count > 0 ? 160 : 130, weight: .black))
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy, value: count)

            Spacer()
            Spacer()
        }
        .foregroundStyle(.white)
        .outlined(width: 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        Color.gray
        GetReadyOverlay(count: 3)
    }
}
