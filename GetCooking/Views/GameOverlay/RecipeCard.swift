//
//  RecipeCardView.swift
//  VisionChef
//
//  The recipe requirements, hanging from the top edge of the screen.
//
//  The icons are the *same* assets the bubbles are built from, so what the
//  player is asked for looks exactly like what they have to grab.
//
//  The card's border doubles as the dish clock: it drains away from the
//  top-right corner around toward the bottom-left, and once under a third is
//  left it turns from green to accent and the whole card starts rocking.
//  Putting the clock here rather than on a separate dial beside the plate
//  means the deadline is drawn *on the thing the deadline is about* — the
//  player is already looking at the recipe.
//

import SwiftUI

struct RecipeCard: View {
    let recipe: Recipe

    /// Read every frame for the clock. Not an `@ObservedObject` binding on the
    /// fraction itself: `dishTimeFraction` is deliberately unpublished (it
    /// changes continuously, and republishing it would re-render the whole HUD
    /// at tick rate), so the TimelineView below polls it instead and only this
    /// card redraws.
    @ObservedObject var gameStateManager: GameStateManager
    
    private var wrongRecipe: Bool  {
        gameStateManager.wrongIngredientPlaced
    }

    private static let iconSize: CGFloat = 100
    private static let iconSpacing: CGFloat = 24
    private static let cornerRadius: CGFloat = 40
    private static let borderWidth: CGFloat = 20

    /// How little time may be left before the card starts rocking.
    private static let urgentThreshold: CGFloat = 1.0 / 3

    /// Rock amplitude in degrees, and how fast it swings.
    private static let wobbleDegrees: Double = 3
    private static let wobbleSpeed: Double = 14

    var body: some View {
        // 30Hz rather than every display frame: the manager's own clock ticks
        // at 30Hz, so redrawing faster would only burn battery redrawing the
        // same border.
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            let fraction = timeRemaining
            let wobble = wobbleAngle(at: timeline.date, fraction: fraction)

            card(timeRemaining: fraction)
                .rotationEffect(.degrees(wobble))
        }
    }

    /// How much of the dish clock is left, 1 down to 0.
    ///
    /// Full whenever the dish isn't being timed — an assembled dish waiting to
    /// be carried to the tray is safe, and a border draining while the player
    /// walks it over would say the opposite.
    private var timeRemaining: CGFloat {
        gameStateManager.isTimingDish ? gameStateManager.dishTimeFraction : 1
    }

    /// The dish is close to timing out. Drives both the rocking and the border
    /// turning from green to accent, so the two can never disagree about when
    /// the player is running late.
    private func isUrgent(_ fraction: CGFloat) -> Bool {
        gameStateManager.isTimingDish && fraction < Self.urgentThreshold
    }

    /// Derived from the timeline's own clock rather than driven by a repeating
    /// `withAnimation`, so it needs no state to start, stop or reset — the
    /// wobble simply exists while the dish is running out and stops when the
    /// next dish resets the fraction.
    private func wobbleAngle(at date: Date, fraction: CGFloat) -> Double {
        guard isUrgent(fraction) else { return 0 }
        return sin(date.timeIntervalSinceReferenceDate * Self.wobbleSpeed) * Self.wobbleDegrees
    }

    private func card(timeRemaining fraction: CGFloat) -> some View {
        VStack(alignment: .center, spacing: 8) {
            // The reserve sets the width; the real icons are centred on top of
            // it. Sizing to the longest possible recipe is what stops the score
            // and heart cards from sliding whenever the dish changes, and
            // overlaying keeps a short recipe centred rather than pushed left.
            widthReserve
                .overlay { ingredientRow }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 20)
        .background {
            if wrongRecipe {
                Color.red.opacity(0.85)
                    .transition(.opacity)
            } else {
                Color.white
            }
        }
        .animation(
            wrongRecipe
                ? .easeInOut(duration: 0.2).repeatForever(autoreverses: true)
                : .default,
            value: wrongRecipe
        )
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: Self.cornerRadius,
                bottomTrailingRadius: Self.cornerRadius
            )
        )
        .overlay {
            CardBorder(cornerRadius: Self.cornerRadius)
                // Keeps the tail end — so the drained part is the *start* of
                // the path, the top-right corner, working toward bottom-left.
                .trim(from: 1 - fraction, to: 1)
                // Green while there is time, accent once the clock is nearly
                // out — the same moment the card starts rocking, so colour and
                // motion land together rather than warning twice.
                .stroke(
                    isUrgent(fraction) ? Color.appAccent : Color.appPrimary,
                    style: StrokeStyle(
                        lineWidth: Self.borderWidth,
                        lineCap: .square
                    )
                )
        }
    }

    /// The dish's actual ingredients.
    private var ingredientRow: some View {
        HStack(spacing: Self.iconSpacing) {
            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, ingredient in
                Image(uiImage: TrimmedArt.image(named: ingredient.imageName) ?? UIImage())
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.iconSize, height: Self.iconSize)
                    .shadow(color: .black.opacity(0.55), radius: 4, y: 2)
            }
        }
    }

    /// Invisible row at the widest a recipe can be, laid out with the same
    /// metrics as the real one so the two can never disagree.
    private var widthReserve: some View {
        HStack(spacing: Self.iconSpacing) {
            ForEach(0..<Recipe.maxIngredientCount, id: \.self) { _ in
                Color.clear
                    .frame(width: Self.iconSize, height: Self.iconSize)
            }
        }
    }
}

/// The card's outline, drawn as an *open* path so it can be trimmed.
///
/// Starts at the top-right corner and runs down, along the bottom and back up
/// the left side to the top-left. That start point is what makes the clock
/// drain the way it should: trimming off the front of the path eats the
/// top-right corner first and travels toward the bottom-left.
///
/// A closed `UnevenRoundedRectangle` can't be used here — its path starts
/// wherever SwiftUI decides, so the drain would begin from an arbitrary corner.
struct CardBorder: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(cornerRadius, min(rect.width, rect.height) / 2)

        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))

        return path
    }
}

#Preview {
    RecipeCard(recipe: .salad, gameStateManager: GameStateManager())
}
