//
//  SkeletonOutline.swift
//  GetCooking
//
//  Draws a set of bone chains — lines between joints, with a dot at each —
//  over the camera feed. Shared by the hand and body overlays so the two read
//  as one debug view rather than two lookalikes drifting apart.
//

import SwiftUI

struct SkeletonOutline: View {
    /// One chain per bone run, already in view space.
    let chains: [[CGPoint]]
    let tint: Color

    var lineWidth: CGFloat = 4
    var jointSize: CGFloat = 10

    var body: some View {
        ZStack {
            // Bones
            ForEach(Array(chains.enumerated()), id: \.offset) { _, chain in
                Path { path in
                    guard let first = chain.first else { return }

                    path.move(to: first)

                    for joint in chain.dropFirst() { path.addLine(to: joint) }
                }
                .stroke(
                    tint.opacity(0.85),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: tint.opacity(0.9), radius: 6)
            }

            // Joints
            ForEach(Array(chains.flatMap { $0 }.enumerated()), id: \.offset) { _, joint in
                Circle()
                    .fill(.white)
                    .frame(width: jointSize, height: jointSize)
                    .shadow(color: tint, radius: 4)
                    .position(joint)
            }
        }
    }
}
