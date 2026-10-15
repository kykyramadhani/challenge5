//
//  TrackingDiagnosticsNode.swift
//  PlayFeat
//
//  Debug-only overlay for tuning hand tracking on a real iPad: next to each
//  hand, which side the tracker thinks it is, whether it was seen or is
//  coasting on a prediction, and how confident it is; across the top, the
//  chop detector's state and why the last frame did or didn't count.
//  Turned on with the `-debugTracking YES` launch argument.
//

#if DEBUG
import OSLog
import SpriteKit

final class TrackingDiagnosticsNode: SKNode {
    /// One hand's line of text and where to draw it, in scene space.
    struct HandLine {
        let id: Int
        let position: CGPoint
        let text: String
    }

    private let summary = SKLabelNode(fontNamed: "Menlo-Bold")
    private let lastDecision = SKLabelNode(fontNamed: "Menlo-Bold")
    private var handLabels: [Int: SKLabelNode] = [:]
    private var previousVerdict: ChopDetector.Verdict?
    private let log = Logger(subsystem: "com.reability.playfeat", category: "ChopDetector")

    init(topLeft: CGPoint) {
        super.init()
        zPosition = 500
        for (index, label) in [summary, lastDecision].enumerated() {
            label.fontSize = 18
            label.fontColor = .yellow
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .top
            label.position = CGPoint(x: topLeft.x, y: topLeft.y - CGFloat(index) * 24)
            addChild(label)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(_ lines: [HandLine]) {
        let live = Set(lines.map(\.id))
        for (id, label) in handLabels where !live.contains(id) {
            label.removeFromParent()
            handLabels[id] = nil
        }
        for line in lines {
            let label = handLabels[line.id] ?? makeHandLabel(id: line.id)
            label.text = line.text
            label.position = CGPoint(x: line.position.x, y: line.position.y + 70)
        }
    }

    /// The chop detector's state after a frame, and that frame's verdict.
    /// Logged only when the verdict changes, so the console stays readable.
    func record(_ verdict: ChopDetector.Verdict, detector: ChopDetector) {
        summary.text = "chop  L:\(Self.name(detector.leftHeight))  R:\(Self.name(detector.rightHeight))"
            + "  last:\(Self.name(detector.lastPose))"
        lastDecision.text = Self.describe(verdict)
        guard verdict != previousVerdict else { return }
        previousVerdict = verdict
        log.debug("\(Self.describe(verdict), privacy: .public)")
    }

    private func makeHandLabel(id: Int) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.fontSize = 16
        label.fontColor = .white
        addChild(label)
        handLabels[id] = label
        return label
    }

    private static func describe(_ verdict: ChopDetector.Verdict) -> String {
        switch verdict {
        case let .chop(from, to): "CHOP ✓ \(name(from)) → \(name(to))"
        case let .armed(pose): "armed at \(name(pose))"
        case let .holding(pose): "holding \(name(pose)) (no repeat)"
        case let .rejected(reason): "rejected: \(reason)"
        }
    }

    private static func name(_ height: ChopDetector.Height?) -> String {
        switch height {
        case .up: "UP"
        case .down: "DOWN"
        case nil: "UNKNOWN"
        }
    }

    private static func name(_ pose: ChopDetector.Pose?) -> String {
        switch pose {
        case .leftUpRightDown: "A(L↑R↓)"
        case .leftDownRightUp: "B(L↓R↑)"
        case nil: "none"
        }
    }
}
#endif
