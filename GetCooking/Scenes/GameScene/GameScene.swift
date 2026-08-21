//
//  GameScene.swift
//  VisionChef
//
//  The transparent SpriteKit layer drawn over the camera feed.
//
//  This file contains the class declaration, all stored properties,
//  lifecycle hooks, the per-frame update loop, and the state machine
//  that reacts to GameStateManager transitions.
//
//  The remaining logic is split across extension files:
//    GameScene+Layout.swift     – plate, reset, positioning
//    GameScene+Spawning.swift   – ingredient bubble creation & placement
//    GameScene+Serving.swift    – finished dish, bell cue, serve animation
//    GameScene+HandInput.swift  – hand tracking, grab/release, cursors
//

import SpriteKit
import SwiftUI

final class GameScene: SKScene {
    
    // MARK: - Injected dependencies
    //
    // Weak so that when the game is finished, it will be de allocated from the memory.
    weak var gameStateManager: GameStateManager?
    weak var handPoseManager: HandPoseManager?

    // MARK: - Layout metrics
    //
    // Everything scales off the shorter screen edge so one set of
    // numbers works from iPhone SE to iPad Pro.

    var shortEdge: CGFloat { min(size.width, size.height) }
    var plateRadius: CGFloat { (shortEdge * 0.17).vc_clamped(to: 70...150) }
    var resetRadius: CGFloat { (shortEdge * 0.09).vc_clamped(to: 38...60) }
    var ingredientRadius: CGFloat { (shortEdge * 0.17).vc_clamped(to: 68...100) }

    /// How deep the SwiftUI HUD reaches down from the top of the screen.
    ///
    /// The score, recipe and hearts cards are opaque and sit above the scene,
    /// so nothing the player must see or reach may be placed under them —
    /// spawned bubbles and a carried plate alike.
    var hudExclusion: CGFloat { max(170, size.height * 0.16) }

    let grabSlack: CGFloat = 30

    /// How much of the gap to the hand a carried ingredient closes in one
    /// 60Hz frame.
    ///
    /// The tracker publishes at camera rate (30Hz) while the scene draws at 60
    /// or 120, so assigning the cursor straight to the node makes a dragged
    /// bubble step rather than glide, and passes every last bit of tracking
    /// jitter through to it.
    var dragSmoothing: CGFloat = 0.5

    /// How long a hand must keep reading as open before what it is carrying is
    /// let go. Short enough to feel immediate, long enough to ride out the
    /// stray frame where a fist is misread — see `HandTracker.openSince`.
    var releaseDelay: TimeInterval = 0.18

    /// How long a hand that is carrying something survives Vision losing it.
    /// Longer than an empty hand gets, because dropping an ingredient is far
    /// more disruptive than a cursor blinking out.
    var heldHandGrace: TimeInterval = 0.35

    /// How much the plate shrinks while it is being carried to the serving
    /// tray. Small enough to drop into the tray's well, big enough that the
    /// dish on it is still readable on the way over.
    var carriedPlateScale: CGFloat = 0.62

    /// Timestamp of the previous `update(_:)`, for frame-rate independent
    /// easing. Zero until the first frame has been seen.
    var lastUpdateTime: TimeInterval = 0

    /// Gap between one bubble popping in and the next. Staggered rather than
    /// all-at-once so the table fills in visibly, but a recipe plus its two
    /// decoys is up to six bubbles — at a full second each the player spent
    /// the first six seconds of the round waiting for the board.
    let spawnInterval: TimeInterval = 0.35
    let spawnActionKey = "spawnSequence"
    /// Separate from `spawnActionKey` so discarding a plate mid-spawn cancels
    /// neither the queued spawns nor, in reverse, the bubbles coming back.
    let returnActionKey = "returnToTable"

    // MARK: - Scene nodes
    var plateNode: PlateNode!
    var resetNode: ResetButtonNode!

    /// Arc drawn around the bin while a discard dwell is charging.
    var resetProgressNode: SKShapeNode?
    var finishedDishNode: SKNode?
    var bellNode: BellNode?

    // MARK: - Carrying the plate to the bell
    //
    // Only one plate exists, so this lives on the scene rather than in
    // `HandTracker` — there is nothing per-hand to remember beyond which hand
    // currently has it.

    /// Which hand is carrying the plate, if any.
    var plateHeldBy: Int?

    /// When that hand first read as open, for the same release debounce that
    /// ingredients use.
    var plateOpenSince: TimeInterval?

    // MARK: - Hand tracking state
    var trackers: [Int: HandTracker] = [:]
    var cursorNodes: [Int: SKShapeNode] = [:]
    var resetHoverDetector = HoverDetector()

    // MARK: - State-machine bookkeeping
    var lastKnownState: GameState?
    var lastResetToken: Int = 0
    var lastDiscardToken: Int = 0
    var spawnedRecipeName: String?
    var lastServeDirection: SwipeDirection?

    /// Where the plate sits. SpriteKit is y-up, so 0.18 is near the bottom.
    var plateHome: CGPoint {
        CGPoint(x: size.width / 2, y: size.height * 0.18)
    }

    // MARK: - Lifecycle
    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
    }
    
    // When initializing for .sks
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    override func didMove(to view: SKView) {
        buildStaticNodes()
        syncWithGameState(force: true)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutStaticNodes()
    }

    // MARK: - Per-frame update

    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        lastUpdateTime = currentTime

        syncWithGameState(force: false)
        updateHandInput(now: currentTime, delta: delta)
    }

    // MARK: - State machine
    /// Polled once per frame. Compares the current GameState against the
    /// last-seen state and runs the appropriate scene transition.
    func syncWithGameState(force: Bool) {
        guard let gameStateManager else { return }

        var force = force
        if gameStateManager.resetToken != lastResetToken {
            lastResetToken = gameStateManager.resetToken
            resetBoard()
            force = true
        }

        if gameStateManager.discardToken != lastDiscardToken {
            lastDiscardToken = gameStateManager.discardToken
            returnPlateContentsToTable()
        }

        let state = gameStateManager.state
        guard force || state != lastKnownState else { return }
        lastKnownState = state

        switch state {
        case .idle:
            break

        case .cooking:
            if let direction = lastServeDirection {
                // The tray is still holding the served plate — animateServe
                // slides it off and clears it, so it must not be torn down
                // here first or the dish vanishes on the spot.
                lastServeDirection = nil
                animateServe(direction: direction, then: gameStateManager.currentRecipe)
            } else {
                bellNode?.removeFromParent()
                bellNode = nil
                finishedDishNode?.removeFromParent()
                finishedDishNode = nil
                spawnIngredientsIfNeeded(for: gameStateManager.currentRecipe)
            }

        case .dishComplete:
            spawnedRecipeName = nil
            clearTableIngredientNodes()
            showFinishedDish(gameStateManager.currentRecipe)

        case .waitingToServe:
            if let side = gameStateManager.bellSide {
                showBell(on: side)
            }

        case .gameOver:
            break
        }
    }
}
