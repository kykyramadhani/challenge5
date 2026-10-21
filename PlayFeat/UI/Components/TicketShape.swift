//
//  TicketShape.swift
//  PlayFeat
//
//  The order ticket's outline from Figma: square top (it hangs from the top
//  of the screen), rounded bottom corners, and a half-circle bite out of each
//  side where the ticket tears in two. A short (two-item) ticket ends at the
//  tear, so its bottom corners are the bites.
//
//  The outline starts at the top-right corner and runs clockwise down the
//  right side, along the bottom and up the left side. The ticket closes it
//  with the top edge; the active ticket's timer border (`sidesAndBottom`)
//  leaves the top open, as in Figma, and trimming it shrinks the border back
//  toward the top-right corner.
//

import SwiftUI

struct TicketShape: Shape {
    var isShort = false

    /// Where the tear sits on a full ticket, and how big the bites are.
    static let tearHeight: CGFloat = 147.5
    private static let biteRadius: CGFloat = 9.5
    private static let cornerRadius: CGFloat = 16.5

    func path(in rect: CGRect) -> Path {
        var path = sidesAndBottom(in: rect)
        path.closeSubpath()
        return path
    }

    /// The outline without its top edge, which hangs from the screen's top
    /// and never shows the order clock.
    func sidesAndBottom(in rect: CGRect) -> Path {
        isShort ? shortTicket(in: rect) : fullTicket(in: rect)
    }

    private func fullTicket(in rect: CGRect) -> Path {
        let bite = Self.biteRadius, corner = Self.cornerRadius
        let tear = rect.minY + rect.height * (Self.tearHeight / 295)
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: tear - bite))
        path.addArc(center: CGPoint(x: rect.maxX, y: tear), radius: bite,
                    startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        path.addArc(center: CGPoint(x: rect.maxX - corner, y: rect.maxY - corner), radius: corner,
                    startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + corner, y: rect.maxY - corner), radius: corner,
                    startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: tear + bite))
        path.addArc(center: CGPoint(x: rect.minX, y: tear), radius: bite,
                    startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        return path
    }

    private func shortTicket(in rect: CGRect) -> Path {
        let bite = Self.biteRadius
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bite))
        path.addArc(center: CGPoint(x: rect.maxX, y: rect.maxY), radius: bite,
                    startAngle: .degrees(-90), endAngle: .degrees(-180), clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX + bite, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX, y: rect.maxY), radius: bite,
                    startAngle: .degrees(0), endAngle: .degrees(-90), clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        return path
    }
}
