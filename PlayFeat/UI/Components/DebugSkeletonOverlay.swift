//
//  DebugSkeletonOverlay.swift
//  PlayFeat
//
//  Draws the tracked body and hands over the camera feed, so a developer can
//  see exactly what Vision is following. Debug builds only.
//

#if DEBUG
import SwiftUI

struct DebugSkeletonOverlay: View {
    var handPoseManager: HandPoseManager

    var body: some View {
        ZStack {
            BodySkeletonView(handPoseManager: handPoseManager)
            HandSkeletonView(handPoseManager: handPoseManager)
        }
        .ignoresSafeArea()
    }
}
#endif
