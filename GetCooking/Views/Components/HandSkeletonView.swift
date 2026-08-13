//
//  HandSkeletonView.swift
//  VisionChef
//
//  Draws every tracked hand — bones plus joint dots — over the camera feed, so
//  you can see what Vision sees. Each hand glows green while it reads as a
//  fist, which makes the grab threshold visible instead of guesswork.
//

import SwiftUI

struct HandSkeletonView: View {
    @ObservedObject var handPoseManager: HandPoseManager

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(handPoseManager.hands) { hand in
                    HandOutline(
                        chains: handPoseManager.jointChains(for: hand, in: proxy.size),
                        tint: hand.isClosedFist ? .green : .cyan
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct HandOutline: View {
    let chains: [[CGPoint]]
    let tint: Color

    var body: some View {
        ZStack {
            // Bones
            ForEach(Array(chains.enumerated()), id: \.offset) { _, chain in
                Path { path in
                    guard let first = chain.first else { return }
                    
                    path.move(to: first)
                    
                    for joint in chain.dropFirst() { path.addLine(to: joint) }
                }
                .stroke(tint.opacity(0.85), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .shadow(color: tint.opacity(0.9), radius: 6)
            }

            // Joints
            ForEach(Array(chains.flatMap { $0 }.enumerated()), id: \.offset) { _, joint in
                Circle()
                    .fill(.white)
                    .frame(width: 10, height: 10)
                    .shadow(color: tint, radius: 4)
                    .position(joint)
            }
        }
    }
}
