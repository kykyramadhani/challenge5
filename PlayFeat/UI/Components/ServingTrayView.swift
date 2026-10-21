//
//  ServingTrayView.swift
//  PlayFeat
//
//  A food tray with its dishes in their compartments and, once served, the
//  drink at its bottom-left corner — faded while it's still owed — the tray
//  being assembled, the one on the table, and an order's ticket.
//

import SwiftUI

struct ServingTrayView: View {
    let tray: ServingTray
    let width: CGFloat
    /// The order wants a drink it hasn't had yet: its glass is drawn faded.
    var isDrinkOwed = false

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
                if tray.hasDrink || isDrinkOwed {
                    Image(TrayArt.drinkImage)
                        .resizable()
                        .frame(width: size.width * TrayArt.drinkSize.width,
                               height: size.height * TrayArt.drinkSize.height)
                        .position(point(at: TrayArt.drinkCenter))
                        .opacity(tray.hasDrink ? 1 : 0.35)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: tray)
            .animation(.easeOut(duration: 0.3), value: isDrinkOwed)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Tray"))
    }

    private func point(at fraction: CGPoint) -> CGPoint {
        CGPoint(x: fraction.x * size.width, y: fraction.y * size.height)
    }
}
