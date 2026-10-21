//
//  ShiftClockCard.swift
//  PlayFeat
//
//  Top-left of the Procurement screen: how long the shift has run, in a
//  starry dome, over the hearts left. Figma size, 244 × 151.
//

import SwiftUI

struct ShiftClockCard: View {
    let elapsedSeconds: Int
    let lives: Int
    let startingLives: Int

    static let size = CGSize(width: 244, height: 151)

    private var clockText: String {
        String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image("TimerBackground")
                .resizable()
                .frame(width: 201.7, height: 90.2)
                .overlay {
                    Text(verbatim: clockText)
                        .font(.atkinson(size: 50, weight: .bold).italic())
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .offset(y: 3)
                }
                .offset(x: 20.5, y: 2.1)

            HStack(spacing: 5.4) {
                ForEach(0..<startingLives, id: \.self) { index in
                    Image("Heart")
                        .resizable()
                        .frame(width: 49.3, height: 49.3)
                        .opacity(index < lives ? 1 : 0.25)
                }
            }
            .frame(width: 244, height: 59)
            .background(.kitchenElevated, in: Capsule())
            .offset(y: 92)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Shift time \(clockText), \(lives) lives left"))
    }
}

#Preview {
    ShiftClockCard(elapsedSeconds: 765, lives: 2, startingLives: 3)
        .padding()
        .background(.gray)
}
