//
//  ChefScene.swift
//  PlayFeat
//
//  The Chef's hands, on the shared KitchenScene mechanics:
//
//  - In the kitchen: pick up a floating raw ingredient or a finished dish,
//    and let it go over its station, the Front House portal or the trash.
//  - With the broth pot zoomed in: pinched hands circling over the pot stir
//    the soup (`StirGesture`). Open hands start their circle over; hands
//    coasting through a tracking gap add nothing.
//

import SpriteKit

final class ChefScene: KitchenScene {
    weak var game: ChefGame?

    private var motionStation: ChefGame.Station = .kitchen

    private var kitchen: ChefLayout { ChefLayout(size: size) }

    init(size: CGSize) {
        super.init(size: size, layout: ChefLayout.self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("Kitchen scenes are built in code, never from an .sks file")
    }

    // MARK: - Frame

    override func play(_ hands: [Hand], now: TimeInterval, delta: TimeInterval) {
        guard let game, !game.isOver else {
            putEverythingBack()
            return
        }
        if game.station != motionStation {
            resetMotions()
            motionStation = game.station
        }
        switch game.station {
        case .kitchen: carry(hands, now: now, delta: delta)
        case .stirring: stir(with: hands, game: game, delta: delta)
        }
    }

    // MARK: - Carrying

    override func carryTargets() -> [(item: CarriedItem, rect: CGRect)] {
        guard let game else { return [] }
        var targets: [(item: CarriedItem, rect: CGRect)] = game.bubbles.indices.compactMap { slot in
            game.bubbles[slot].map { bubble in
                let item = CarriedItem.ingredient(bubble.ingredient, cardSlot: slot)
                return (item, kitchen.bubble(at: game.bubbleSpots[item], otherwise: kitchen.bubble(slot)))
            }
        }
        // A finished dish is taken out of the pot itself; once let go
        // elsewhere it's a bubble there.
        for station in ChefGame.stations {
            if let dish = game.pots[station]?.readyIngredient {
                let item = CarriedItem.cooked(dish)
                targets.append((item, kitchen.bubble(at: game.bubbleSpots[item], otherwise: kitchen.pot(station))))
            }
        }
        return targets
    }

    override func dropTargets() -> [(zone: DropZone, rect: CGRect)] { kitchen.dropTargets }

    override func dropPoint(for item: CarriedItem, at zone: DropZone) -> CGPoint { kitchen.center(of: zone) }

    override func accepts(_ item: CarriedItem, at zone: DropZone) -> Bool {
        game?.accepts(item, at: zone) ?? false
    }

    override func drop(_ item: CarriedItem, at zone: DropZone) {
        game?.drop(item, at: zone)
    }

    override func place(_ item: CarriedItem, at spot: CGPoint) -> Bool {
        game?.place(item, at: spot)
        return game?.bubbleSpots[item] != nil
    }

    override func didPickUp(_ item: CarriedItem) { game?.pickUp(item) }

    override func didPutBack(_ item: CarriedItem) { game?.putBack(item) }

    // MARK: - Stirring

    /// Pinched hands circling inside the zoomed-in pot. Both hands add up.
    private func stir(with hands: [Hand], game: ChefGame, delta: TimeInterval) {
        var circles = 0.0
        for hand in handsInWorkArea(hands) {
            switch StirGesture.step(isPinching: hand.isPinching, isPredicted: hand.isPredicted) {
            case .stir: circles += feed(hand, motion: .circles, delta: delta)
            case .restart: resetMotion(of: hand)
            case .hold: break
            }
        }
        if circles > 0 { game.addStir(circles: circles) }
    }
}
