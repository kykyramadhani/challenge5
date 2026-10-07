//
//  GameStateManager.swift
//  PlayFeat
//
//  Runs a game: decides *when* the phase, plate, lives, clocks and score change.
//  The details of each live in their own small types (see Game/).
//

import Foundation
import QuartzCore

@Observable
final class GameStateManager {

    // MARK: - Phase and events

    private(set) var state: GameState = .idle

    /// Everything that happened this run that the phase alone doesn't show.
    /// `GameScene` and the HUD react to each entry once.
    private(set) var events = GameEventLog()

    /// Which run this is, counting from 1. The 3-2-1-GO! countdown restarts
    /// with each one — and only then, never for a life lost mid-run.
    var runNumber: Int { 1 + events.count(of: .runRestarted) }

    /// When true the clocks and the scene are frozen (Pause button). Kept
    /// apart from `state` on purpose: a run can be paused in any phase, and
    /// resuming has to land back in exactly the phase it left.
    private(set) var isPaused = false

    // MARK: - Round

    private(set) var currentRecipe: Recipe
    private(set) var plateContents: [Ingredient] = []

    /// Which edge the bell rang on, and so which way the plate has to be
    /// carried. Nil whenever no dish is waiting to be served.
    var bellSide: SwipeDirection? { state.bellSide }

    /// Something on the plate isn't in the recipe. Worked out from the plate
    /// itself, so it clears the moment the plate is emptied, however that
    /// happens.
    var hasWrongIngredient: Bool {
        plateContents.contains { !currentRecipe.ingredients.contains($0) }
    }

    // MARK: - Run

    /// Lives left. Every dish that times out costs one; at zero the run ends.
    private(set) var lives: Int
    let startingLives: Int

    /// Whether a coin multiplier is active for this run.
    private(set) var hasMultiplier = false

    private var tally = RunTally()
    private var difficulty = Difficulty()

    var dishesByType: [String: Int] { tally.dishesByType }
    var speedBonus: Int { tally.speedBonus }
    var totalDishesServed: Int { tally.totalDishesServed }
    var dishesCompleted: Int { difficulty.dishesServed }
    var spawnStagger: TimeInterval { difficulty.spawnStagger }

    /// A value snapshot of this run's outcome, handed to the results screen so
    /// it needs no live reference back to this manager.
    var result: GameResult {
        GameResult(dishesByType: dishesByType, speedBonus: speedBonus, hasMultiplier: hasMultiplier)
    }

    private let deck: RecipeDeck

    // MARK: - Clocks

    /// Seconds survived so far, whole seconds only. The run has no clock to
    /// beat — it ends when the lives run out — so this counts *up*.
    private(set) var elapsedTime = 0

    /// Deliberately `@ObservationIgnored`: these change every tick (30×/s),
    /// and tracking them would redraw every view that reads a fraction.
    /// `RecipeCard` polls with a TimelineView instead; the HUD reads the
    /// whole-second `elapsedTime`.
    @ObservationIgnored private var clock = PlayClock(wallTime: CACurrentMediaTime())
    @ObservationIgnored private var dishCountdown = Countdown.none
    @ObservationIgnored private var serveCountdown = Countdown.none

    /// What the current dish started with, so the countdown ring knows the
    /// full sweep its fraction is measured against.
    var dishTimeLimit: TimeInterval { dishCountdown.duration }

    /// How long the tray waits for its plate once the bell rings.
    static let serveTimeLimit: TimeInterval = 5

    /// The assembly clock runs only while `.cooking`. The moment the plate
    /// matches, the dish is safe: serving it is on its own clock, so a slow
    /// walk to the bell can never cost the life the player just earned.
    var isTimingDish: Bool { state == .cooking }
    var isTimingServe: Bool { state.isWaitingToServe }

    /// How much of the current dish's clock is left, 1 down to 0.
    var dishTimeFraction: CGFloat { dishCountdown.fractionLeft(at: clock.elapsed) }

    /// How much of the serve window is left, 1 down to 0 — the tray's dial.
    var serveTimeFraction: CGFloat { serveCountdown.fractionLeft(at: clock.elapsed) }

    /// Fine-grained because the countdown ring is drawn from it; that costs no
    /// extra SwiftUI work, since only whole seconds are ever published.
    private static let tickInterval: TimeInterval = 1.0 / 30

    /// How long the finished dish shows on its own before the bell rings —
    /// gives `.dishComplete` a beat to actually be seen (GameScene polls
    /// `state` once per frame) instead of being skipped straight past.
    private static let dishRevealDuration: TimeInterval = 0.9

    /// Below this fraction of the dish clock, the looping low-time warning plays.
    private static let lowTimeWarningFraction: CGFloat = 0.3

    @ObservationIgnored private var timer: Timer?

    init(recipes: [Recipe] = Recipe.all, startingLives: Int = 3) {
        precondition(startingLives > 0, "GameStateManager needs at least one life")
        deck = RecipeDeck(recipes)
        self.startingLives = startingLives
        lives = startingLives
        currentRecipe = deck.randomRecipe()
    }

    deinit { timer?.invalidate() }

    // MARK: - Lifecycle

    /// Moves from `.idle` into the first round and starts the clock. Call
    /// once camera/hand tracking is ready.
    func start() {
        guard state == .idle else { return }
        hasMultiplier = InventoryManager.shared.getMultiplierCount() > 0
        beginDishClock()
        state = .cooking
        startTimer()
    }

    /// Wipes everything back to a brand-new run: score, lives, plate, clocks,
    /// recipe. Leaves `state` at `.idle` rather than starting play — a replay
    /// sits through the seat check and countdown again like the first run,
    /// and `start()` kicks the clock off once that beat is done.
    func restart() {
        timer?.invalidate()
        resetAudioForNewRun()
        tally = RunTally()
        difficulty = Difficulty()
        lives = startingLives
        plateContents = []
        isPaused = false
        clock.reset()
        elapsedTime = 0
        hasMultiplier = InventoryManager.shared.getMultiplierCount() > 0
        currentRecipe = deck.randomRecipe()
        events.record(.runRestarted)
        state = .idle
    }

    func togglePause() {
        guard state != .gameOver else { return }
        isPaused.toggle()
    }

    func gameOver() {
        timer?.invalidate()
        saveResult()
        state = .gameOver
    }

    // MARK: - Plate interaction (called by GameScene)

    /// Registers an ingredient dropped onto the plate and checks for a match.
    func addIngredientToPlate(_ ingredient: Ingredient) {
        guard state == .cooking else { return }
        plateContents.append(ingredient)
        completeDishIfPlateMatches()
    }

    /// Empties the plate but keeps the same recipe, score and clock — the
    /// player dumped a wrong mix and is retrying this dish.
    ///
    /// Ignored when the plate is already empty, so a stray gesture doesn't
    /// replay the animation or disturb a table that's still fine.
    func discardPlate() {
        guard state == .cooking, !plateContents.isEmpty else { return }
        // The on-screen Reset button fires this, so it gets the reset sound.
        AudioManager.shared.play(.reset)
        plateContents = []
        events.record(.plateDiscarded)
    }

    /// Serves the finished dish.
    ///
    /// Called by `GameScene` once the player has carried the plate all the way
    /// to the bell. Arriving there *is* the action, so there is nothing to
    /// check here — `bellSide` only decides which edge it is carried to.
    func serveDish() {
        guard state.isWaitingToServe else { return }
        playServeSounds()
        // Before the next round starts, so the speed-up lands on the very
        // next dish.
        difficulty.recordServedDish()
        startNewRound()
    }

    /// The dish (or serve) clock ran out: costs a life, then either ends the
    /// run or moves on to a fresh dish.
    ///
    /// Internal rather than private so tests can exercise the consequences
    /// without sitting through a real clock.
    func failDish() {
        guard state != .gameOver else { return }
        lives -= 1
        // The dish ran out from under the player — stop its warning and play
        // the lost-life sting instead.
        AudioManager.shared.stopClockWarning()
        AudioManager.shared.play(.loseHeart)
        events.record(.lifeLost(livesLeft: lives))

        guard lives > 0 else {
            gameOver()
            return
        }
        startNewRound()
    }

    /// Multiset comparison: the plate must contain exactly the recipe's
    /// ingredients — no missing pieces, no extras, no wrong substitutions.
    static func matches(plateContents: [Ingredient], recipe: Recipe) -> Bool {
        guard plateContents.count == recipe.ingredients.count else { return false }
        let plateCounts = Dictionary(grouping: plateContents, by: { $0 }).mapValues(\.count)
        let requiredCounts = Dictionary(grouping: recipe.ingredients, by: { $0 }).mapValues(\.count)
        return plateCounts == requiredCounts
    }

    // MARK: - Round transitions

    private func completeDishIfPlateMatches() {
        guard Self.matches(plateContents: plateContents, recipe: currentRecipe) else { return }
        // Banked *now*, while the dish clock still reads the moment of
        // completion — reading it later would under-count.
        tally.recordCompletedDish(currentRecipe, secondsLeft: dishCountdown.wholeSecondsLeft(at: clock.elapsed))
        state = .dishComplete

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.dishRevealDuration) { [weak self] in
            self?.ringBell()
        }
    }

    private func ringBell() {
        guard state == .dishComplete else { return }
        // Started as the bell rings, not when the dish was assembled, so the
        // reveal beat doesn't eat into the player's window.
        serveCountdown = Countdown(duration: Self.serveTimeLimit, startingAt: clock.elapsed)
        state = .waitingToServe(bellSide: Bool.random() ? .left : .right)
    }

    private func startNewRound() {
        plateContents = []
        currentRecipe = deck.recipe(after: currentRecipe)
        beginDishClock()
        state = .cooking
    }

    /// Puts the current recipe's assembly clock on the play clock, squeezed
    /// by the current difficulty tier.
    private func beginDishClock() {
        dishCountdown = Countdown(duration: difficulty.dishTime(for: currentRecipe), startingAt: clock.elapsed)
        // The music speeds up in lock-step with the tier that just squeezed
        // the clock, so the run audibly gets harder.
        AudioManager.shared.setMusicRate(difficulty.musicRate)
    }

    /// Banks the run's coins and high score the instant the run ends.
    ///
    /// Deliberately here rather than in `GameScene`: the scene's update loop
    /// is paused the moment the run is over, so a save riding it only runs if
    /// a frame happens to fire before the freeze — a race it often lost. This
    /// transition runs exactly once per run, so the save always lands.
    private func saveResult() {
        if hasMultiplier {
            InventoryManager.shared.consumeMultiplier()
        }
        GameStorage.record(result)
        GameCenter.submit(totalDishesServed)
    }

    // MARK: - Ticking

    private func startTimer() {
        timer?.invalidate()
        clock.hold(at: CACurrentMediaTime())
        timer = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        let now = CACurrentMediaTime()
        guard !isPaused, state != .gameOver else {
            clock.hold(at: now)
            // No dish is running down, so a warning left looping would keep
            // ticking over a frozen clock.
            AudioManager.shared.stopClockWarning()
            return
        }
        clock.advance(to: now)

        // Only whole seconds reach the HUD, so this publishes once a second.
        let wholeSeconds = Int(clock.elapsed)
        if wholeSeconds != elapsedTime { elapsedTime = wholeSeconds }

        // Each clock only applies in its own phase, so neither can fire while
        // the other is the one actually running.
        if isTimingDish, dishCountdown.hasRunOut(at: clock.elapsed) { failDish() }
        if isTimingServe, serveCountdown.hasRunOut(at: clock.elapsed) { failDish() }

        updateClockWarning()
    }

    // MARK: - Sound

    /// Starts or stops the looping low-time warning to match the dish clock:
    /// only while a dish is being timed and has dropped into its last stretch.
    /// `> 0` leaves out the expired frame, which `failDish()` handles.
    /// Both AudioManager calls are idempotent, so this can run every tick.
    private func updateClockWarning() {
        let runningLow = isTimingDish
            && dishTimeFraction > 0
            && dishTimeFraction <= Self.lowTimeWarningFraction
        if runningLow {
            AudioManager.shared.startClockWarning()
        } else {
            AudioManager.shared.stopClockWarning()
        }
    }

    /// A restart wipes the board, so a low-time warning still looping from
    /// the last run is silenced, and the music drops back to normal speed —
    /// otherwise it would race through the countdown at last run's tempo.
    private func resetAudioForNewRun() {
        AudioManager.shared.stopClockWarning()
        AudioManager.shared.setMusicRate(1.0)
        AudioManager.shared.play(.reset)
    }

    /// The order is handed over, and the reward chime lands a beat later.
    private func playServeSounds() {
        AudioManager.shared.play(.putOrder)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            AudioManager.shared.play(.addPoint)
        }
    }
}
