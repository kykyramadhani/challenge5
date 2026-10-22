//
//  ShiftReportView.swift
//  PlayFeat
//  Created by Owen Limantoro on 21/10/26.
//
//  The end of a shift: what the player did in the role they played and the
//  score it earned. One screen for every role; the rows come from the role's
//  `ShiftReport`.
//

import SwiftUI

struct ShiftReportView: View {
    let report: ShiftReport
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Image("SpaceBackground")
                .resizable()
                .scaledToFill()
                .overlay(Color.black.opacity(0.35))
                .ignoresSafeArea()
                .accessibilityHidden(true)

            reportPanel
                .designScaled()
        }
    }

    private var reportPanel: some View {
        ZStack(alignment: .top) {
            KitchenPanelFrame(size: Layout.panel, cornerRadius: 45)
            scoreCard
                .padding(.top, Layout.cardTop)
            ReportTitleTab()
                .offset(y: -Layout.titleOverhang)
        }
        .frame(width: Layout.panel.width, height: Layout.panel.height)
        .padding(.top, Layout.titleOverhang)
    }

    private var scoreCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(.kitchenElevated)

            Text("OVERALL SCORE")
                .font(.atkinson(size: 48, weight: .heavy))
                .foregroundStyle(.kitchenHeading)
                .position(x: Layout.card.width / 2, y: Layout.headingCenterY)

            OverallScore(score: report.overallScore)
                .position(x: Layout.card.width / 2, y: Layout.scoreCenterY)

            VStack(spacing: Layout.lineSpacing) {
                ForEach(report.lines, id: \.action) { ReportLineRow(line: $0) }
            }
            .position(x: Layout.card.width / 2, y: Layout.linesCenterY)

            ClickButton(action: onContinue) {
                KitchenButtonLabel(title: "CONTINUE", systemImage: "play.fill", size: Layout.button)
            }
            .buttonStyle(.plain)
            .position(x: Layout.card.width / 2, y: Layout.buttonCenterY)
        }
        .frame(width: Layout.card.width, height: Layout.card.height)
    }
}

// MARK: - Layout

/// Figma's shift report frame (1376 × 1034). Positions inside the card are
/// centres, measured from the card's top-left corner.
private enum Layout {
    static let panel = CGSize(width: 765, height: 794)
    static let card = CGSize(width: 671, height: 650)
    static let cardTop: CGFloat = 77
    /// How far the title tab sticks out above the panel.
    static let titleOverhang: CGFloat = 53

    static let headingCenterY: CGFloat = 62
    static let scoreCenterY: CGFloat = 180
    static let line = CGSize(width: 563, height: 102)
    static let lineSpacing: CGFloat = 22
    /// The rows start 282 pt down the card.
    static let linesCenterY: CGFloat = 282 + line.height + lineSpacing / 2
    static let button = CGSize(width: 286, height: 72)
    /// The button's top edge is 530 pt down the card.
    static let buttonCenterY: CGFloat = 530 + (button.height + KitchenButtonLabel.baseDepth) / 2
}

// MARK: - Pieces

private struct ReportTitleTab: View {
    var body: some View {
        Text("SHIFT REPORT")
            .font(.atkinson(size: 44, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 475, height: 108)
            .background(.kitchenHeading, in: RoundedRectangle(cornerRadius: 24))
            .accessibilityAddTraits(.isHeader)
    }
}

private struct OverallScore: View {
    let score: Int

    var body: some View {
        ZStack {
            StarBurst()
                .fill(.scoreGlow)
                .frame(width: 190, height: 190)
                .blur(radius: 6)
                .accessibilityHidden(true)

            Text(verbatim: "\(score)")
                .font(.atkinson(size: 100, weight: .heavy))
                .foregroundStyle(.kitchenInk)
        }
    }
}

/// One action of the shift: how often it was done, and the points it scored.
private struct ReportLineRow: View {
    let line: ShiftReport.Line

    var body: some View {
        HStack(spacing: 16) {
            Text(verbatim: "\(line.count)x")
                .font(.atkinson(size: 30, weight: .heavy))
            Text(line.action.reportTitle)
                .font(.atkinson(size: 24, weight: .bold))
                .lineLimit(2)
            Spacer(minLength: 16)
            Text(verbatim: "\(line.points)")
                .font(.atkinson(size: 44, weight: .heavy))
                .foregroundStyle(.kitchenInk)
        }
        .foregroundStyle(.kitchenHeading)
        .padding(.horizontal, 27)
        .frame(width: Layout.line.width, height: Layout.line.height)
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.trayStandPurple, lineWidth: 1.5)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The spiky glow behind the overall score.
private struct StarBurst: Shape {
    private static let spikes = 14
    /// Inner points sit at this share of the outer radius.
    private static let innerShare: CGFloat = 0.72

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let corners = Self.spikes * 2
        var path = Path()
        for corner in 0..<corners {
            let radius = corner.isMultiple(of: 2) ? outer : outer * Self.innerShare
            let angle = Double(corner) / Double(corners) * 2 * .pi - .pi / 2
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if corner == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

private extension ShiftAction {
    var reportTitle: LocalizedStringKey {
        switch self {
        case .ingredientCutOrTrayWashed: "Ingredients Cut & Tray Washed"
        case .ingredientSent: "Ingredients Sent"
        case .soupCooked: "Soup Cooked"
        case .boiledOrFried: "Boiled & Fried"
        case .orderServed: "Order Served"
        case .beverageMade: "Beverage Made"
        }
    }
}

#Preview {
    var report = ShiftReport(role: .chef)
    for _ in 0..<3 { report.record(.soupCooked) }
    report.record(.boiledOrFried)
    return ShiftReportView(report: report, onContinue: {})
        .environment(AudioManager())
}
