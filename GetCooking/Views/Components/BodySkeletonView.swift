//
//  BodySkeletonView.swift
//  GetCooking
//
//  Draws the upper body of the one person the game is listening to — the
//  shoulder line, and the sides of the torso when the hips are in shot.
//
//  Only ever one body: whoever else is in frame is filtered out upstream, so
//  if a second skeleton appears here something is wrong with the filter.
//

import SwiftUI

struct BodySkeletonView: View {
    @ObservedObject var handPoseManager: HandPoseManager

    /// Distinct from the hands' green and cyan, so it is obvious at a glance
    /// which detector drew what.
    var tint: Color = .yellow

    var body: some View {
        GeometryReader { proxy in
            SkeletonOutline(
                chains: handPoseManager.bodyChains(in: proxy.size),
                tint: tint,
                lineWidth: 6,
                jointSize: 14
            )
        }
        .allowsHitTesting(false)
    }
}
