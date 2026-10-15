//
//  FloatingBubbles.swift
//  PlayFeat
//
//  The five floating bubbles of the Chef and Front House. Each one flies in
//  from the portal its ingredient came through when it arrives, and is
//  hidden while a hand carries it (the carried copy is drawn by the scene).
//

import SwiftUI

struct FloatingBubbles: View {
    let bubbles: [FloatingBubble?]
    var isCooked = false
    let slotRect: (Int) -> CGRect
    /// The portal a bubble's ingredient arrives through.
    let sourceRect: (KitchenIngredient) -> CGRect
    let isHeld: (Int, FloatingBubble) -> Bool

    private let bubbleSize = CGSize(width: IngredientBubble.size, height: IngredientBubble.size)

    var body: some View {
        ForEach(bubbles.indices, id: \.self) { slot in
            if let bubble = bubbles[slot] {
                IngredientBubble(ingredient: bubble.ingredient, isCooked: isCooked, bobDelay: Double(slot) * 0.35)
                    .opacity(isHeld(slot, bubble) ? 0 : 1)
                    .id(bubble.id)
                    .transition(.asymmetric(insertion: arrival(of: bubble, at: slot), removal: .opacity))
                    .placed(in: slotRect(slot), designSize: bubbleSize)
            }
        }
        .animation(.easeOut(duration: 0.8), value: bubbles.map { $0?.id })
    }

    /// Starts small at its portal and floats out to its slot. In the
    /// bubble's own (unscaled) points, since `placed` scales it after.
    private func arrival(of bubble: FloatingBubble, at slot: Int) -> AnyTransition {
        let target = slotRect(slot)
        let source = sourceRect(bubble.ingredient)
        let scale = target.width / IngredientBubble.size
        let from = CGSize(width: (source.midX - target.midX) / scale, height: (source.midY - target.midY) / scale)
        return .offset(from).combined(with: .scale(scale: 0.3)).combined(with: .opacity)
    }
}
