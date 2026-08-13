//
//  GameStateManager.swift
//  VisionChef
//
//  The game's state machine. Owns the current recipe, the plate's contents,
//  score, the round clock, and the transitions between cooking a dish and
//  serving it.
//

import Foundation
import Combine

enum GameState: Equatable {
    /// Before the game has started (e.g. waiting on camera permission).
    case idle
    /// Ingredients are on the table; the player is assembling the plate.
    case cooking
    /// The plate matched the active recipe; the finished dish is showing.
    case dishComplete
    /// A swipe-direction cue is showing; waiting for the player to serve.
    case waitingForSwipe
    /// The round timer hit zero; play is over until `restart()`.
    case gameOver
}

final class GameStateManager: ObservableObject {

    @Published private(set) var state: GameState = .idle
    @Published private(set) var currentRecipe: Recipe
    @Published private(set) var score: Int = 0
    @Published private(set) var plateContents: [Ingredient] = []
    @Published private(set) var swipeCueDirection: SwipeDirection?

    /// Seconds left on the round clock. Reaches 0 → `.gameOver`.
    @Published private(set) var remainingTime: Int
    /// When true the clock and the scene are frozen (Pause button).
    @Published private(set) var isPaused: Bool = false

    /// Bumped on every fresh game. `GameScene` watches this rather than the
    /// state alone, because restarting can land on the same state *and* the
    /// same recipe as before — leaving the old ingredients on screen, which is
    /// exactly the "Play Again does nothing" bug.
    @Published private(set) var resetToken: Int = 0

    /// Bumped when the player swipes down to dump the plate. `GameScene` plays
    /// the fly-away animation and respawns off this.
    @Published private(set) var discardToken: Int = 0

    /// Total time for a game.
    let roundDuration: Int

    private let recipePool: [Recipe]
    private var timer: Timer?

    init(recipes: [Recipe] = Recipe.all, roundDuration: Int = 60) {
        precondition(!recipes.isEmpty, "GameStateManager needs at least one recipe")
        self.recipePool = recipes
        self.roundDuration = roundDuration
        self.remainingTime = roundDuration
        self.currentRecipe = recipes.randomElement()!
    }

    deinit { timer?.invalidate() }

    // MARK: - Lifecycle

    /// Moves the state machine from `.idle` into the first cooking round and
    /// starts the countdown. Call once camera/hand tracking is ready.
    func start() {
        guard state == .idle else { return }
        state = .cooking
        startTimer()
    }

    /// Wipes everything back to a brand-new game: score, plate, clock, recipe.
    /// Bumping `resetToken` is what tells `GameScene` to clear the board.
    func restart() {
        timer?.invalidate()
        score = 0
        plateContents = []
        swipeCueDirection = nil
        isPaused = false
        remainingTime = roundDuration
        currentRecipe = recipePool.randomElement()!
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
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard !isPaused, state != .gameOver else { return }
        guard remainingTime > 0 else { return }
        remainingTime -= 1
        if remainingTime == 0 {
            timer?.invalidate()
            state = .gameOver
        }
    }

    // MARK: - Plate interaction (called by GameScene)

    /// Registers an ingredient dropped onto the plate and checks for a match.
    func addIngredientToPlate(_ ingredient: Ingredient) {
        guard state == .cooking else { return }
        plateContents.append(ingredient)
        checkForCompletion()
    }

    /// Empties the plate but keeps the same recipe, score and clock — the
    /// player swiped down to dump a wrong mix and is retrying this dish.
    ///
    /// Ignored when the plate is already empty, so a stray downward swipe
    /// doesn't replay the animation or respawn a table that's still fine.
    func discardPlate() {
        guard state == .cooking, !plateContents.isEmpty else { return }
        plateContents = []
        discardToken += 1
    }

    // MARK: - Serving (called by ContentView in response to HandPoseManager)

    /// Attempts to serve the finished dish. Succeeds only while waiting for
    /// a swipe and only when the swipe direction matches the shown cue.
    func handleSwipe(_ direction: SwipeDirection) {
        guard state == .waitingForSwipe, direction == swipeCueDirection else { return }
        score += currentRecipe.scoreValue
        swipeCueDirection = nil
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
        currentRecipe = nextRecipe()
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
