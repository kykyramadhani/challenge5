//
//  SeatCalibrationView.swift
//  PlayFeat
//
//  The seat check before a run or a kitchen shift: the player sits back far
//  enough that their upper body — shoulders down to hips — fits the frame.
//  Whoever passes it is the player the hand pipeline follows from then on.
//
//  The border is the whole feedback loop. Orange while the pose is wrong;
//  once it is right, a green border draws itself over the orange one, and the
//  game starts when it closes the loop.
//

import QuartzCore
import SwiftUI

struct SeatCalibrationView: View {
    var handPoseManager: HandPoseManager

    /// Called once the player has held the pose for the full dwell.
    var onCalibrated: () -> Void

    /// The way out for a player the camera can't find, or who can't get into
    /// the pose: without it the check is a dead end.
    var onBack: () -> Void

    /// Set from the Settings sheet. In one-hand mode only the chosen hand has
    /// to be raised — the pose is otherwise impossible to hold  with one arm
    /// unavailable.
    @AppStorage(HandInputModeSetting.isOneHandKey) private var isOneHand = false
    @AppStorage(HandInputModeSetting.preferredHandKey) private var preferredHand: HandSide = .right

    private var inputMode: any HandInputMode {
        HandInputModeSetting.mode(isOneHand: isOneHand, preferredHand: preferredHand)
    }

    /// Same dwell detector the bin gesture uses, so "hold still for a moment"
    /// behaves identically across the game and the timing rules live in one
    /// place — including the stall cap that stops a hitch completing it.
    @State private var detector = HoverDetector()
    @State private var progress: CGFloat = 0

    /// The body publishes at camera rate, but a player sitting perfectly still
    /// stops publishing, so the dwell is driven by its own clock instead.
    private static let tickInterval: Duration = .milliseconds(33)

    // MARK: - Layout
    private static let screenSize = DesignCanvas.size

    /// The target box in that frame. It hangs off the bottom edge, so its
    /// bottom border sits just below the screen and the player's body reads
    /// as rising into it from below.
    private static let calibrationBox = CGRect(x: 138, y: 278, width: 1100, height: 786)

    /// The instruction sits this far above the box's top edge (to its centre).
    private static let instructionLift: CGFloat = 61

    /// Smallest share of the *screen's* width the player's shoulders may
    /// span: the "don't sit right at the back of the room" check. Tied to the
    /// screen, not the box, so making the box bigger doesn't make players sit
    /// closer. (It was a quarter of a box 54% of the screen wide.)
    private static let minimumShoulderShare: CGFloat = 0.135

    /// Guide silhouette width, as a share of the box.
    private static let guideShare: CGFloat = 0.63

    private static let cornerRadius: CGFloat = 40
    private static let borderWidth: CGFloat = 12
    private static let instructionSize: CGFloat = 44

    /// Where the player has to put themselves: the Figma box, scaled with the
    /// design canvas, centred, and hung off the bottom of the screen. Also
    /// handed to the pose pipeline: until calibration passes, nobody outside
    /// it is the player.
    static func targetFrame(in size: CGSize) -> CGRect {
        let scale = DesignCanvas.scale(for: size)
        let width = calibrationBox.width * scale
        let distanceFromBottom = (screenSize.height - calibrationBox.minY) * scale
        return CGRect(
            x: (size.width - width) / 2,
            y: size.height - distanceFromBottom,
            width: width,
            height: calibrationBox.height * scale
        )
    }

    /// The fewest points the player's shoulders may span on a screen this size.
    static func minimumShoulderSpan(in size: CGSize) -> CGFloat {
        size.width * minimumShoulderShare
    }

    var body: some View {
        // The camera feed belongs to the screen hosting this check, and stays
        // put across the handover to play; this only draws over it. So does
        // the camera-permission card, shown once by the host.
        ZStack {
            GeometryReader { proxy in
                let frame = Self.targetFrame(in: proxy.size)
                let scale = DesignCanvas.scale(for: proxy.size)

                ZStack {
                    Text(instructionText)
                        .font(.atkinson(size: Self.instructionSize * scale, weight: .black))
                        .foregroundStyle(.white)
                        .outlined(width: 4 * scale)
                        .position(x: frame.midX, y: frame.minY - Self.instructionLift * scale)

                    border(scale: scale)
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                }
                .onChange(of: proxy.size, initial: true) { _, size in
                    handPoseManager.setPlayerZone(Self.targetFrame(in: size), in: size)
                }
                .task(id: proxy.size) { await runDwell(in: proxy.size) }
            }
            .allowsHitTesting(false)

            BackButton(action: onBack)
        }
        .onAppear { handPoseManager.start() }
    }

    /// Fills the border while the player holds the pose, and reports the pass
    /// once. Restarts if the screen is resized, since the frame moves with it.
    private func runDwell(in size: CGSize) async {
        let frame = Self.targetFrame(in: size)
        while !Task.isCancelled {
            // Read every tick rather than captured from the body, so the dwell
            // always sees the player's current position, even in frames where
            // nothing republished.
            let aligned = isAligned(in: size, frame: frame)
            let finished = detector.update(isHovering: aligned, now: CACurrentMediaTime())
            progress = detector.progress
            if finished {
                onCalibrated()
                return
            }
            try? await Task.sleep(for: Self.tickInterval)
        }
    }

    /// Orange underneath, green drawn over the top of it as the dwell fills —
    /// so the progress reads as the frame turning good, rather than as a
    /// separate gauge the player has to interpret.
    private func border(scale: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius * scale)
        let edge = SeatFrameEdge(cornerRadius: Self.cornerRadius * scale)
        let lineWidth = Self.borderWidth * scale
        return ZStack {
            shape
                .fill(.white.opacity(0.15))
                .overlay(alignment: .bottom) { guide }
                .clipShape(shape)

            // An open edge rather than a closed rectangle: the box's bottom
            // hangs off the screen, and a closed shape would spend part of the
            // fill tracing it out of sight. The fill runs in one stroke, up
            // the left side, across the top and down the right.
            edge
                .stroke(.appTertiary, lineWidth: lineWidth)
            edge
                .trim(from: 0, to: progress)
                .stroke(.appPrimary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
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

    /// Routed through `AppLocalization` rather than `Text` with a plain
    /// `String`: this is a computed `String`, and `Text(String)` renders its
    /// argument verbatim with no catalog lookup at all — which is how this
    /// stayed in English regardless of the language picker.
    private var instructionText: String {
        AppLocalization.string(inputMode.calibrationInstruction)
    }

    private func isAligned(in size: CGSize, frame: CGRect) -> Bool {
        guard let body = handPoseManager.playerBody(in: size) else { return false }
        return body.isAligned(
            in: frame,
            minimumShoulderSpan: Self.minimumShoulderSpan(in: size),
            mode: inputMode
        )
    }
}

/// The seat frame's visible edge, in one stroke: up the left side from the
/// bottom, round both top corners, and down the right side. Open at the
/// bottom, because that edge is off the screen.
private struct SeatFrameEdge: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.minY),
            radius: cornerRadius
        )
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.maxY),
            radius: cornerRadius
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}
