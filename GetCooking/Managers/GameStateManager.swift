//
//  GameStateManager.swift
//  VisionChef
//
//  The game's state machine. Owns the current recipe, the plate's contents,
//  score, lives, the clocks, and the transitions between cooking a dish and
//  serving it.
//

import Combine
import Foundation
import QuartzCore

final class GameStateManager: ObservableObject {

    @Published private(set) var state: GameState = .idle
    @Published private(set) var currentRecipe: Recipe
    @Published private(set) var plateContents: [Ingredient] = []

    /// How many dishes of each kind the player completed this run, keyed by the
    /// recipe's `finishedDishImageName` (e.g. "salad", "ChickenGeprek"). The
    /// PostGame paycheck reads these for its per-dish tally.
    @Published private(set) var dishesByType: [String: Int] = [:]

    /// Total seconds of leftover dish-clock banked across the run. A dish
    /// finished with 3 seconds still on its clock adds 3 here — the paycheck's
    /// "Speed Bonus".
    @Published private(set) var speedBonus: Int = 0

    /// Every dish completed this run, all kinds summed — the paycheck's
    /// "Dishes Served" count.
    var totalDishesServed: Int { dishesByType.values.reduce(0, +) }

    /// Whether a coin multiplier is active for this run.
    @Published private(set) var hasMultiplier: Bool = false

    /// A value snapshot of this run's outcome, handed to the results screen so
    /// it needs no live reference back to this manager.
    var result: GameResult {
        GameResult(dishesByType: dishesByType, speedBonus: speedBonus, hasMultiplier: hasMultiplier)
    }

    /// Which edge the bell rang on, and so which way the plate has to be
    /// carried. Nil whenever no dish is waiting to be served.
    @Published private(set) var bellSide: SwipeDirection?

    /// Seconds survived so far. The run has no clock to beat — it ends when
    /// the lives run out — so this counts *up*, and is what PostGame reports.
    @Published private(set) var elapsedTime: Int = 0

    /// Lives left. Every dish that times out costs one; at zero the run ends.
    @Published private(set) var lives: Int
    @Published var looseHeart: Bool = false

    /// When true the clocks and the scene are frozen (Pause button).
    @Published private(set) var isPaused: Bool = false

    /// Bumped whenever `GameScene` must wipe the board outright: a fresh game,
    /// or a dish that timed out. Both change the recipe without necessarily
    /// changing `state`, so the scene has no transition to key off — comparing
    /// state alone was the "Play Again does nothing" bug.
    ///
    /// Serving is deliberately *not* in here: that keeps its slide-out
    /// animation, which needs the old plate and dish still on screen.
    @Published private(set) var resetToken: Int = 0

    /// Bumped when the player dumps the plate. `GameScene` floats the contents
    /// back onto the table off this.
    @Published private(set) var discardToken: Int = 0

    /// Bumped only when a brand-new run begins — i.e. `restart()`, never
    /// `failDish()`. `GameplayView` keys its 3-2-1-GO! countdown off this
    /// rather than `resetToken`: losing a life also wipes the board, but the
    /// run is still going and the player should not be made to sit through
    /// another countdown to carry on.
    @Published private(set) var runToken: Int = 0
    
    @Published var wrongIngredientPlaced = false

    let startingLives: Int

    private let recipePool: [Recipe]
    private var timer: Timer?

    init(recipes: [Recipe] = Recipe.all, startingLives: Int = 3) {
        precondition(!recipes.isEmpty, "GameStateManager needs at least one recipe")
        precondition(startingLives > 0, "GameStateManager needs at least one life")
        self.recipePool = recipes
        self.startingLives = startingLives
        self.lives = startingLives
        self.currentRecipe = recipes.randomElement()!
    }

    deinit { timer?.invalidate() }

    // MARK: - Dish clock
    //
    // Everything is measured against `playClock`, which only advances while
    // the game is actually running. Pausing therefore needs no compensation
    // anywhere else: the clock simply stops, and every deadline expressed on
    // it stays valid.

    /// Seconds of unpaused play.
    ///
    /// Deliberately not `@Published`: `GameScene` reads `dishTimeFraction` off
    /// it every frame, and republishing at frame rate would re-render the
    /// whole SwiftUI HUD for a shape only SpriteKit draws. The whole-second
    /// mirror the HUD *does* want is `elapsedTime`.
    private var playClock: TimeInterval = 0
    private var lastTick: TimeInterval = CACurrentMediaTime()

    /// `playClock` reading at which the current dish runs out.
    private var dishDeadline: TimeInterval = 0

    /// What the current dish started with, so the countdown ring knows the
    /// full sweep its fraction is measured against.
    private(set) var dishTimeLimit: TimeInterval = 0

    // MARK: - Difficulty ramp
    //
    // The run gets harder the longer it lasts: every few served dishes the
    // assembly clock is squeezed, so the same recipes have to be built faster.
    // This lives on served dishes, not elapsed time, so a player who takes it
    // slow ramps up at the same rate as one who rushes — progress, not the
    // wall clock, is what raises the stakes.

    /// Dishes successfully served this run. Published so the HUD could show a
    /// level later; it only changes once per dish, never per frame, so it
    /// costs no per-frame re-render.
    @Published private(set) var dishesCompleted: Int = 0

    /// How many served dishes between each speed-up step.
    private static let dishesPerSpeedUp = 5

    /// How much the clock tightens at each step. 1.25 means each new tier gets
    /// 1 / 1.25 = 80% of the time the previous tier had for the same dish.
    private static let speedUpFactor: Double = 1.2

    /// A floor on the squeezed time, so a very long run stays *hard* rather
    /// than tipping into impossible. Tune or remove to taste.
    private static let minimumDishTime: TimeInterval = 2.0

    /// The compounding multiplier for the current tier: `speedUpFactor` raised
    /// to the number of speed-up steps reached so far. 0–4 dishes → 1.0,
    /// 5–9 → 1.25, 10–14 → 1.5625, and so on.
    private var difficultyMultiplier: Double {
        pow(Self.speedUpFactor, Double(dishesCompleted / Self.dishesPerSpeedUp))
    }

    /// Base stagger between one ingredient bubble popping in and the next,
    /// before any speed-up — the pace a round fills in at on the first tier.
    private static let baseSpawnStagger: TimeInterval = 0.2

    /// A floor on the squeezed stagger, so even a very long run's board still
    /// fills in visibly rather than snapping in all at once.
    private static let minimumSpawnStagger: TimeInterval = 0.1

    /// The gap between bubbles popping in when a round is laid out, tightened
    /// by the same difficulty tier that squeezes the dish clock — so a later
    /// board both *appears* faster and has less time to be cleared. `GameScene`
    /// reads this each time it spawns a round.
    var spawnStagger: TimeInterval {
        max(Self.baseSpawnStagger / difficultyMultiplier, Self.minimumSpawnStagger)
    }

    /// How strongly the music tempo tracks the difficulty tier. `1.0` makes the
    /// music speed equal `difficultyMultiplier` outright (so 1.25× on the first
    /// speed-up); lower values ramp the tempo up more gently than the clock.
    /// Tune to taste — 0.5 gives a noticeable-but-not-frantic climb.
    private static let musicTempoIntensity: Float = 0.3

    /// The background-music playback speed for the current tier. On tier 0 it is
    /// `1.0` (normal speed) and it climbs from there, blended toward normal by
    /// `musicTempoIntensity` and clamped to the `0.5...2.0` range `AVAudioPlayer`
    /// honours. `AudioManager.setMusicRate` clamps too, so this can never drive
    /// the player out of range.
    var musicRate: Float {
        let blended = 1.0 + (Float(difficultyMultiplier) - 1.0) * Self.musicTempoIntensity
        return min(max(blended, 0.5), 2.0)
    }

    /// Whether the assembly clock is running.
    ///
    /// Only while `.cooking`. The moment the plate matches, the dish is safe:
    /// the ring disappears and serving it is untimed, so a slow walk to the
    /// bell can never cost the life the player just earned their way out of.
    var isTimingDish: Bool { state == .cooking }

    /// How much of the current dish's clock is left, 1 down to 0.
    var dishTimeFraction: CGFloat {
        guard dishTimeLimit > 0 else { return 0 }
        return CGFloat((dishDeadline - playClock) / dishTimeLimit).vc_clamped(to: 0...1)
    }

    // MARK: - Serve clock
    //
    // Once the bell rings the player has a short window to carry the plate to
    // the tray. Measured on `playClock` like everything else, so pausing
    // costs nothing.

    /// How long the tray waits for its plate.
    static let serveTimeLimit: TimeInterval = 5

    /// `playClock` reading at which the waiting order is abandoned.
    private var serveDeadline: TimeInterval = 0

    /// Whether the serve window is counting down.
    var isTimingServe: Bool { state == .waitingToServe }

    /// How much of the serve window is left, 1 down to 0 — what the tray's
    /// dial is drawn from.
    var serveTimeFraction: CGFloat {
        guard Self.serveTimeLimit > 0 else { return 0 }
        return CGFloat((serveDeadline - playClock) / Self.serveTimeLimit).vc_clamped(to: 0...1)
    }

    /// How often the clock advances. Fine-grained because the countdown ring
    /// is drawn from it; that costs no extra SwiftUI work, since only whole
    /// seconds of `elapsedTime` are ever published.
    private static let tickInterval: TimeInterval = 1.0 / 30

    /// The largest slice of wall clock a single tick may credit.
    ///
    /// A stall — or coming back from a pause or the background — must not hand
    /// the player a dish failure they never saw coming. Same guard, for the
    /// same reason, as `HoverDetector.maxFrameGap`.
    private static let maxTickDelta: TimeInterval = 0.25

    // MARK: - Lifecycle

    /// Moves the state machine from `.idle` into the first round and starts
    /// the clock. Call once camera/hand tracking is ready.
    func start() {
        guard state == .idle else { return }
        hasMultiplier = InventoryManager.shared.getMultiplierCount() > 0
        beginDishClock()
        state = .cooking
        startTimer()
    }

    /// Wipes everything back to a brand-new run: score, lives, plate, clocks,
    /// recipe. Bumping `resetToken` is what tells `GameScene` to clear the
    /// board. Leaves `state` at `.idle` rather than starting play immediately
    /// — a replay has to sit through the seat check and countdown again just
    /// like the first run, and `start()` is what actually kicks the clock off
    /// once that beat is done.
    func restart() {
        timer?.invalidate()
        // A restart wipes the board, so any low-time warning still looping from
        // the run that just ended has to be silenced explicitly.
        AudioManager.shared.stopClockWarning()
        
        // A fresh run starts on tier 0, so drop the music back to normal speed —
        // otherwise it would still be racing at last run's tempo through the
        // countdown until the first dish resets it.
        AudioManager.shared.setMusicRate(1.0)
        AudioManager.shared.play(.reset)
        dishesByType = [:]
        speedBonus = 0
        lives = startingLives
        plateContents = []
        bellSide = nil
        isPaused = false
        playClock = 0
        elapsedTime = 0
        dishesCompleted = 0
        hasMultiplier = InventoryManager.shared.getMultiplierCount() > 0
        currentRecipe = recipePool.randomElement()!
        resetToken += 1
        runToken += 1
        state = .idle
    }

    // MARK: - Timer + pause

    func togglePause() {
        guard state != .gameOver else { return }
        isPaused.toggle()
    }

    private func startTimer() {
        timer?.invalidate()
        lastTick = CACurrentMediaTime()
        timer = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        // Advanced even while paused, so resuming doesn't credit the whole
        // pause to the dish in one go.
        let now = CACurrentMediaTime()
        let delta = min(now - lastTick, Self.maxTickDelta)
        lastTick = now

        guard !isPaused, state != .gameOver else {
            // No dish is running down while paused or after the run ends, so a
            // low-time warning left looping would keep ticking over a frozen
            // clock — silence it here.
            AudioManager.shared.stopClockWarning()
            return
        }
        playClock += delta

        // Only whole seconds reach the HUD, so this publishes once a second
        // rather than at the tick rate.
        let whole = Int(playClock)
        if whole != elapsedTime { elapsedTime = whole }

        // `isTimingDish` and not just the deadline: each clock only applies in
        // the phase it belongs to, so neither can fire while the other is the
        // one actually running.
        if isTimingDish, playClock >= dishDeadline { failDish() }
        if isTimingServe, playClock >= serveDeadline { failDish() }

        // Kept in sync with the dish clock every tick — both AudioManager calls
        // are idempotent, so re-asserting the current state costs nothing.
        updateClockWarning()
    }

    /// Below this fraction of the dish clock, the looping low-time warning plays.
    private static let lowTimeWarningFraction: CGFloat = 0.3

    /// Starts or stops the low-time warning so it matches the dish clock.
    ///
    /// Only while a dish is actually being timed and it has dropped into the
    /// last stretch. `dishTimeFraction > 0` excludes the expired frame, which
    /// `failDish()` handles as its own event rather than as "low on time".
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

    /// Puts the current recipe's assembly clock on `playClock`, squeezed by
    /// the current difficulty tier and never dropping below the floor.
    private func beginDishClock() {
        dishTimeLimit = max(currentRecipe.timeLimit / difficultyMultiplier, Self.minimumDishTime)
        dishDeadline = playClock + dishTimeLimit
        // Push the music tempo up in lock-step with the tier that just squeezed
        // the clock, so the track audibly speeds up as the run gets harder.
        AudioManager.shared.setMusicRate(musicRate)
    }

    /// The dish clock ran out: costs a life, then either ends the run or moves
    /// on to a fresh dish.
    ///
    /// Internal rather than private so tests can exercise the consequences
    /// without sitting through a real ten-second clock.
    func failDish() {
        guard state != .gameOver else { return }
        lives -= 1
        looseHeart = true
        // The dish ran out from under the player — stop the warning it was
        // making and play the lost-life sting instead.
        AudioManager.shared.stopClockWarning()
        AudioManager.shared.play(.loseHeart)

        guard lives > 0 else {
            gameOver()
            return
        }

        startNewRound()
        // The recipe changed but the state may not have — a dish can time out
        // while already `.cooking` — so the scene needs telling explicitly.
        resetToken += 1
    }
    
    func gameOver() {
        timer?.invalidate()
        persistResult()
        state = .gameOver
    }

    // MARK: - Persistence

    /// Banks the run's coins and high score into `GameStorage` the instant the
    /// run ends.
    ///
    /// Deliberately here, in the model, rather than in `GameScene`: the scene's
    /// `update(_:)` loop is paused the moment the run is over (`GameplayView`
    /// sets `scene.isPaused` on `.gameOver`), and a save riding that loop only
    /// runs if a frame happens to fire before the freeze — a race it often
    /// loses, which is why the save only *sometimes* stuck. This transition
    /// runs exactly once per run, so the save always lands.
    private func persistResult() {
        if hasMultiplier {
            InventoryManager.shared.consumeMultiplier()
        }
        let outcome = result
        GameStorage.coins += outcome.totalCoins
        // Read before the write, so `newHighScore` still compares against the
        // *previous* best rather than the value we are about to store.
        if outcome.newHighScore {
            GameStorage.highscore = outcome.totalDishesServed
        }
        GameCenter.submit(outcome.totalDishesServed)
    }

    // MARK: - Plate interaction (called by GameScene)

    /// Registers an ingredient dropped onto the plate and checks for a match.
    func addIngredientToPlate(_ ingredient: Ingredient) {
        guard state == .cooking else { return }
        plateContents.append(ingredient)
        checkForCompletion()
    }

    /// Empties the plate but keeps the same recipe, score and clock — the
    /// player dumped a wrong mix and is retrying this dish.
    ///
    /// Ignored when the plate is already empty, so a stray gesture doesn't
    /// replay the animation or disturb a table that's still fine.
    func discardPlate() {
        guard state == .cooking, !plateContents.isEmpty else { return }
        // The on-screen Reset button is what fires this, so it gets the reset
        // sound as its feedback — the dish itself keeps its recipe and clock.
        AudioManager.shared.play(.reset)
        plateContents = []

        // Reset Wrong State
        wrongIngredientPlaced = false

        discardToken += 1
    }

    // MARK: - Serving

    /// Serves the finished dish.
    ///
    /// Called by `GameScene` once the player has carried the plate all the way
    /// to the bell. Arriving there *is* the action, so there is nothing to
    /// check against here — `bellSide` only decides which edge it is carried to.
    func serveDish() {
        guard state == .waitingToServe else { return }
        // The order is handed over…
        AudioManager.shared.play(.putOrder)
        // …and the reward chime lands a beat later.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            AudioManager.shared.play(.addPoint)
        }
        // Counts only served dishes — a timed-out dish (failDish) doesn't ramp
        // difficulty. startNewRound() reads the new count when it begins the
        // next dish's clock, so the speed-up lands on the very next dish.
        dishesCompleted += 1
        startNewRound()
    }

    // MARK: - Internal transitions

    /// How long the finished dish shows on its own before the swipe cue
    /// appears — gives `.dishComplete` a beat to actually be observed
    /// (GameScene polls `state` once per frame) instead of being skipped
    /// straight through to `.waitingToServe`.
    private static let dishRevealDuration: TimeInterval = 0.9

    private func checkForCompletion() {
        guard Self.matches(plateContents: plateContents, recipe: currentRecipe) else { return }
        // Bank the dish and its leftover time *now*, while the dish clock still
        // reads the moment of completion — it keeps ticking down as the player
        // carries the plate to the bell, so reading it later would under-count.
        recordCompletedDish()
        state = .dishComplete
        
        // The plate is right
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.dishRevealDuration) { [weak self] in
            guard let self, self.state == .dishComplete else { return }
            self.bellSide = Bool.random() ? .left : .right
            // Started as the bell rings, not when the dish was assembled, so
            // the reveal beat above doesn't eat into the player's window.
            self.serveDeadline = self.playClock + Self.serveTimeLimit
            self.state = .waitingToServe
        }
    }

    /// Records a just-completed dish: adds it to its per-type tally and banks
    /// however many whole seconds were left on its clock as speed bonus.
    private func recordCompletedDish() {
        dishesByType[currentRecipe.finishedDishImageName, default: 0] += 1

        // Whole seconds still on the clock — floored, so 3.7s left banks 3.
        let secondsLeft = max(0, Int(dishDeadline - playClock))
        speedBonus += secondsLeft
    }

    private func startNewRound() {
        // Reset Wrong State
        wrongIngredientPlaced = false
        
        plateContents = []
        bellSide = nil
        currentRecipe = nextRecipe()
        beginDishClock()   // also bumps the music tempo for the new tier
        state = .cooking
    }

    private func nextRecipe() -> Recipe {
        guard recipePool.count > 1 else { return recipePool[0] }
        var candidate = recipePool.randomElement()!
        while candidate.name == currentRecipe.name {
            candidate = recipePool.randomElement()!
        }
        return candidate
    }

    /// Multiset comparison: the plate must contain exactly the recipe's
    /// ingredients — no missing pieces, no extras, no wrong substitutions.
    static func matches(plateContents: [Ingredient], recipe: Recipe) -> Bool {
        guard plateContents.count == recipe.ingredients.count else { return false }
        let plateCounts = Dictionary(grouping: plateContents, by: { $0 }).mapValues(\.count)
        let requiredCounts = Dictionary(grouping: recipe.ingredients, by: { $0 }).mapValues(\.count)
        return plateCounts == requiredCounts
    }
}
