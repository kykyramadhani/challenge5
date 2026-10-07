//
//  Difficulty.swift
//  PlayFeat
//
//  How hard the run is: every few *served* dishes the clock tightens, so
//  progress — not the wall clock — raises the stakes.
//

import Foundation

struct Difficulty {
    /// How many served dishes between each speed-up step.
    private static let dishesPerSpeedUp = 5

    /// How much the clock tightens at each step. 1.2 means each new tier gets
    /// 1 / 1.2 ≈ 83% of the time the previous tier had for the same dish.
    private static let speedUpFactor: Double = 1.2

    /// A floor on the squeezed time, so a very long run stays *hard* rather
    /// than tipping into impossible.
    private static let minimumDishTime: TimeInterval = 2.0

    /// The gap between bubbles popping in on the first tier.
    private static let baseSpawnStagger: TimeInterval = 0.2

    /// A floor on the squeezed stagger, so even a very long run's board still
    /// fills in visibly rather than snapping in all at once.
    private static let minimumSpawnStagger: TimeInterval = 0.1

    /// How strongly the music tempo tracks the tier. 1.0 would make the music
    /// speed equal the multiplier outright; lower values climb more gently.
    private static let musicTempoIntensity: Float = 0.3

    private(set) var dishesServed = 0

    mutating func recordServedDish() {
        dishesServed += 1
    }

    /// `speedUpFactor` raised to the number of steps reached so far:
    /// 0–4 dishes → 1.0, 5–9 → 1.2, 10–14 → 1.44, and so on.
    private var multiplier: Double {
        pow(Self.speedUpFactor, Double(dishesServed / Self.dishesPerSpeedUp))
    }

    /// The assembly time `recipe` gets on the current tier.
    func dishTime(for recipe: Recipe) -> TimeInterval {
        max(recipe.timeLimit / multiplier, Self.minimumDishTime)
    }

    /// The gap between bubbles popping in when a round is laid out. Tightened
    /// by the same tier, so a later board both *appears* faster and has less
    /// time to be cleared.
    var spawnStagger: TimeInterval {
        max(Self.baseSpawnStagger / multiplier, Self.minimumSpawnStagger)
    }

    /// The background-music playback speed: 1.0 on the first tier, climbing
    /// from there, clamped to the 0.5...2.0 range `AVAudioPlayer` honours.
    var musicRate: Float {
        let blended = 1.0 + (Float(multiplier) - 1.0) * Self.musicTempoIntensity
        return min(max(blended, 0.5), 2.0)
    }
}
