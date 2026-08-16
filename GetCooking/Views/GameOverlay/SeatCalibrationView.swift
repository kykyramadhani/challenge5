//
//  SeatCalibrationView.swift
//  GetCooking
//
//  The screen between the main menu and the game: the player sits back far
//  enough that their upper body — shoulders down to hips — fits the frame.
//
//  The border is the whole feedback loop. Orange while the pose is wrong;
//  once it is right, a green border draws itself over the orange one, and the
//  game starts when it closes the loop.
//

import AVFoundation
import Combine
import QuartzCore
import SwiftUI

struct SeatCalibrationView: View {
    @ObservedObject var handPoseManager: HandPoseManager

    /// Called once the player has held the pose for the full dwell.
    var onCalibrated: () -> Void

    /// Same dwell detector the bin gesture uses, so "hold still for a moment"
    /// behaves identically across the game and the timing rules live in one
    /// place — including the stall cap that stops a hitch completing it.
    @State private var detector = HoverDetector()
    @State private var progress: CGFloat = 0

    /// The body publishes at camera rate, but a player sitting perfectly still
    /// stops publishing, so the dwell is driven by its own clock instead.
    private let tick = Timer.publish(every: 1 / 30, on: .main, in: .common).autoconnect()

    // MARK: - Layout

    /// Target box, as a fraction of the screen.
    private static let frameShare = CGSize(width: 0.54, height: 0.42)

    /// Smallest share of the box's width the player's shoulders may span.
    /// This is the "don't sit right at the back of the room" check.
    private static let minimumShoulderShare: CGFloat = 0.25

    /// Guide silhouette width, as a share of the box.
    private static let guideShare: CGFloat = 0.53

    private static let cornerRadius: CGFloat = 40
    private static let borderWidth: CGFloat = 12

    /// Where the player has to put themselves.
    static func targetFrame(in size: CGSize) -> CGRect {
        let box = CGSize(
            width: size.width * frameShare.width,
            height: size.height * frameShare.height
        )
        return CGRect(
            x: (size.width - box.width) / 2,
            y: (size.height - box.height) / 2,
            width: box.width,
            height: box.height
        )
    }

    var body: some View {
        // The camera itself is mounted by ContentView and stays put across the
        // handover to the game; this screen only draws over it.
        ZStack {
            // The player needs to see what the tracker sees to know why they
            // are not passing yet.
            BodySkeletonView(handPoseManager: handPoseManager)
                .ignoresSafeArea()

            GeometryReader { proxy in
                let frame = Self.targetFrame(in: proxy.size)

                VStack(spacing: 0) {
                    Text("Adjust your seat to fit in the frame")
                        .font(.system(size: 44, weight: .black))
                        .foregroundStyle(.white)
                        .outlined(width: 4)
                        .frame(maxHeight: .infinity, alignment: .center)

                    border
                        .frame(width: frame.width, height: frame.height)

                    Spacer(minLength: 0)
                        .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onReceive(tick) { _ in
                    // Recomputed here rather than captured from the body, so
                    // the dwell always reads the player's current position even
                    // in frames where nothing republished.
                    let aligned = isAligned(in: proxy.size, frame: frame)
                    let finished = detector.update(isHovering: aligned, now: CACurrentMediaTime())

                    progress = detector.progress
                    if finished { onCalibrated() }
                }
            }
            .allowsHitTesting(false)

            if handPoseManager.authorizationStatus == .denied
                || handPoseManager.authorizationStatus == .restricted
            {
                CameraPermissionDeniedOverlay()
            }
        }
        .onAppear { handPoseManager.start() }
    }

    /// Orange underneath, green drawn over the top of it as the dwell fills —
    /// so the progress reads as the frame turning good, rather than as a
    /// separate gauge the player has to interpret.
    private var border: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .fill(.white.opacity(0.15))
                .overlay(alignment: .bottom) { guide }
                .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))

            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .stroke(.accent, lineWidth: Self.borderWidth)

            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .trim(from: 0, to: progress)
                .stroke(
                    Color("Primary"),
                    style: StrokeStyle(lineWidth: Self.borderWidth, lineCap: .round)
                )
        }
    }

    /// The pose to copy: head and shoulders in the frame with both hands up.
    ///
    /// Drawn as a white silhouette rather than the artwork's own grey, which
    /// disappears against dark clothing on a live camera. Bottom-anchored and
    /// clipped, so it reads as the player's own body filling the frame.
    private var guide: some View {
        GeometryReader { box in
            Image("CalibrationGuide")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: box.size.width * Self.guideShare)
                .foregroundStyle(.white.opacity(0.45))
                .shadow(color: .black.opacity(0.35), radius: 8)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .bottom
                )
        }
    }

    private func isAligned(in size: CGSize, frame: CGRect) -> Bool {
        guard let body = handPoseManager.playerBody(in: size) else { return false }
        return body.isAligned(
            in: frame,
            minimumShoulderSpan: frame.width * Self.minimumShoulderShare
        )
    }
}
