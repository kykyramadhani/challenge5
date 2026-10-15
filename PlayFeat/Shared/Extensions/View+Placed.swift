//
//  View+Placed.swift
//  PlayFeat
//
//  Puts a view built at its Figma size onto a layout rect: scaled to the
//  rect's width and centred on it. Lets components keep Figma's numbers while
//  ProcurementLayout decides where they land on each iPad.
//

import SwiftUI

extension View {
    func placed(in rect: CGRect, designSize: CGSize) -> some View {
        frame(width: designSize.width, height: designSize.height)
            .scaleEffect(rect.width / designSize.width)
            .position(x: rect.midX, y: rect.midY)
    }
}
