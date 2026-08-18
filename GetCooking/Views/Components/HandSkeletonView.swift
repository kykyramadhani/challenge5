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
                    SkeletonOutline(
                        chains: handPoseManager.jointChains(for: hand, in: proxy.size),
                        tint: hand.isClosedFist ? .green : .cyan
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
