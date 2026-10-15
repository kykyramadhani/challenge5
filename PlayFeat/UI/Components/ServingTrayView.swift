//
//  ServingTrayView.swift
//  PlayFeat
//
//  A food tray with its dishes in their compartments and, when there is one,
//  the drink at its bottom-left corner — the tray being assembled, the one
//  on the table, and an order's ticket.
//

import SwiftUI

struct ServingTrayView: View {
    let tray: ServingTray
    let width: CGFloat

    private var size: CGSize { CGSize(width: width, height: width / TrayArt.aspectRatio) }

    var body: some View {
        TrayArtView(isDirty: false, size: size)
            .overlay {
                ForEach(TrayCompartment.allCases, id: \.self) { compartment in
                    if let dish = tray.dishes[compartment] {
                        IngredientArt(ingredient: dish, size: width * TrayArt.dishWidth, isPrepared: true)
                            .position(point(at: TrayArt.center(of: compartment)))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                if tray.hasDrink {
                    Image(TrayArt.drinkImage)
                        .resizable()
                        .frame(width: size.width * TrayArt.drinkSize.width,
                               height: size.height * TrayArt.drinkSize.height)
                        .position(point(at: TrayArt.drinkCenter))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: tray)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Tray"))
    }

    private func point(at fraction: CGPoint) -> CGPoint {
        CGPoint(x: fraction.x * size.width, y: fraction.y * size.height)
    }
}
