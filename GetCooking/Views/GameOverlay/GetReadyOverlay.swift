//
//  GetReadyOverlay.swift
//  GetCooking
//
//  The 3-2-1 between passing the seat check and the first recipe landing.
//
//  Deliberately shown over a live board — camera, plate and HUD all visible
//  behind it — so the player can settle their hands before anything is asked
//  of them.
//

import SwiftUI

struct GetReadyOverlay: View {
    /// Seconds left. 3, 2, 1 — never 0; the overlay is gone by then.
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

            Text("\(count)")
                .font(.system(size: 160, weight: .black))
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
