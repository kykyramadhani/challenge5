//
//  PanelProgressBar.swift
//  PlayFeat
//
//  The cream bar at the bottom of a workstation panel. With three segments
//  each one turns green per completed chop; with one it fills smoothly as the
//  tray is scrubbed. Figma size, 580 × 91.
//

import SwiftUI

struct PanelProgressBar: View {
    /// 0...1.
    let progress: Double
    var segments = 1

    static let size = CGSize(width: 580, height: 91)
    private let trackSize = CGSize(width: 549, height: 65)
    private let gap: CGFloat = 21

    private var segmentWidth: CGFloat {
        (trackSize.width - gap * CGFloat(segments - 1)) / CGFloat(segments)
    }

    var body: some View {
        HStack(spacing: gap) {
            ForEach(0..<segments, id: \.self) { index in
                segment(filled: fill(of: index))
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(.kitchenElevated, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 3.6))
        .shadow(color: .black.opacity(0.2), radius: 0, y: 4)
        .accessibilityElement()
        .accessibilityValue(Text("\(Int(progress * 100)) percent"))
    }

    /// How much of segment `index` is green, 0...1.
    private func fill(of index: Int) -> CGFloat {
        CGFloat(min(max(progress * Double(segments) - Double(index), 0), 1))
    }

    private func segment(filled: CGFloat) -> some View {
        Capsule()
            .fill(.kitchenTrack)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(.progressGreen)
                    .frame(width: segmentWidth * filled)
                    .opacity(filled > 0 ? 1 : 0)
            }
            .frame(width: segmentWidth, height: trackSize.height)
            .animation(.easeOut(duration: 0.25), value: filled)
    }
}

#Preview {
    VStack {
        PanelProgressBar(progress: 2.0 / 3, segments: 3)
        PanelProgressBar(progress: 0.6)
    }
    .padding()
    .background(.kitchenPageTint)
}
