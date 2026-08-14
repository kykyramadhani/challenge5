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

enum GameState: Equatable {
    /// Before the game has started (e.g. waiting on camera permission).
    case idle
    /// Ingredients are on the table; the player is assembling the plate.
    case cooking
    /// The plate matched the active recipe; the finished dish is showing.
    case dishComplete
    /// A swipe-direction cue is showing; waiting for the player to serve.
    case waitingForSwipe
    /// The player ran out of lives; play is over until `restart()`.
    case gameOver
}

final class GameStateManager: ObservableObject {

    @Published private(set) var state: GameState = .idle
    @Published private(set) var currentRecipe: Recipe
    @Published private(set) var score: Int = 0
    @Published private(set) var plateContents: [Ingredient] = []
    @Published private(set) var swipeCueDirection: SwipeDirection?

    /// Seconds survived so far. The run has no clock to beat — it ends when
    /// the lives run out — so this counts *up*, and is what PostGame reports.
    @Published private(set) var elapsedTime: Int = 0

    /// Lives left. Every dish that times out costs one; at zero the run ends.
    @Published private(set) var lives: Int

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

    /// Whether the assembly clock is running.
    ///
    /// Only while `.cooking`. The moment the plate matches, the dish is safe:
    /// the ring disappears and serving it is untimed, so a slow swipe can
    /// never cost the life the player just earned their way out of.
    var isTimingDish: Bool { state == .cooking }

    /// How much of the current dish's clock is left, 1 down to 0.
    var dishTimeFraction: CGFloat {
        guard dishTimeLimit > 0 else { return 0 }
        return CGFloat((dishDeadline - playClock) / dishTimeLimit).vc_clamped(to: 0...1)
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
        beginDishClock()
        state = .cooking
        startTimer()
    }

    /// Wipes everything back to a brand-new run: score, lives, plate, clocks,
    /// recipe. Bumping `resetToken` is what tells `GameScene` to clear the board.
    func restart() {
        timer?.invalidate()
        score = 0
        lives = startingLives
        plateContents = []
        swipeCueDirection = nil
        isPaused = false
        playClock = 0
        elapsedTime = 0
        currentRecipe = recipePool.randomElement()!
        beginDishClock()
        resetToken += 1
        state = .cooking
        startTimer()
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

        guard !isPaused, state != .gameOver else { return }
        playClock += delta

        // Only whole seconds reach the HUD, so this publishes once a second
        // rather than at the tick rate.
        let whole = Int(playClock)
        if whole != elapsedTime { elapsedTime = whole }

        // `isTimingDish` and not just the deadline: an assembled dish waiting
        // to be served must not run out from under the player.
        if isTimingDish, playClock >= dishDeadline { failDish() }
    }

    /// Puts the current recipe's assembly clock on `playClock`.
    private func beginDishClock() {
        dishTimeLimit = currentRecipe.timeLimit
        dishDeadline = playClock + dishTimeLimit
    }

    /// The dish clock ran out: costs a life, then either ends the run or moves
    /// on to a fresh dish.
    ///
    /// Internal rather than private so tests can exercise the consequences
    /// without sitting through a real ten-second clock.
    func failDish() {
        guard state != .gameOver else { return }
        lives -= 1

        guard lives > 0 else {
            timer?.invalidate()
            state = .gameOver
            return
        }

        startNewRound()
        // The recipe changed but the state may not have — a dish can time out
        // while already `.cooking` — so the scene needs telling explicitly.
        resetToken += 1
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
        plateContents = []
        discardToken += 1
    }

    // MARK: - Serving

    /// Attempts to serve the finished dish. Succeeds only while waiting for
    /// a swipe and only when the swipe direction matches the shown cue.
    func handleSwipe(_ direction: SwipeDirection) {
        guard state == .waitingForSwipe, direction == swipeCueDirection else { return }
        score += currentRecipe.scoreValue
        startNewRound()
    }

    // MARK: - Internal transitions

    /// How long the finished dish shows on its own before the swipe cue
    /// appears — gives `.dishComplete` a beat to actually be observed
    /// (GameScene polls `state` once per frame) instead of being skipped
    /// straight through to `.waitingForSwipe`.
    private static let dishRevealDuration: TimeInterval = 0.9

    private func checkForCompletion() {
        guard Self.matches(plateContents: plateContents, recipe: currentRecipe) else { return }
        state = .dishComplete
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.dishRevealDuration) { [weak self] in
            guard let self, self.state == .dishComplete else { return }
            self.swipeCueDirection = Bool.random() ? .left : .right
            self.state = .waitingForSwipe
        }
    }

    private func startNewRound() {
        plateContents = []
        swipeCueDirection = nil
        currentRecipe = nextRecipe()
        beginDishClock()
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
