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

    /// Countdown pie for the current dish. Sized and placed off the plate so
    /// it reads as belonging to it, tucked against the lower right where it
    /// clears both the bubbles and the finished dish.
    var dishTimerRadius: CGFloat { plateRadius * 0.36 }
    var dishTimerHome: CGPoint {
        CGPoint(x: plateHome.x + plateRadius, y: plateHome.y - plateRadius * 0.85)
    }

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
    var dishTimerNode: DishTimerNode!
    
    /// Arc drawn around the bin while a discard dwell is charging.
    var resetProgressNode: SKShapeNode?
    var finishedDishNode: SKNode?
    var swipeCueNode: SKNode?

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

        consumeSwipe()
        syncWithGameState(force: false)
        updateDishTimer()
        updateHandInput(now: currentTime, delta: delta)
    }

    /// Drives the countdown pie beside the plate.
    ///
    /// Read straight off the manager each frame rather than observed: the
    /// fraction changes continuously, and publishing it would re-render the
    /// entire SwiftUI HUD for a shape only SpriteKit draws.
    func updateDishTimer() {
        guard let gameStateManager, gameStateManager.isTimingDish else {
            dishTimerNode?.isHidden = true
            return
        }
        dishTimerNode?.isHidden = false
        dishTimerNode?.update(fraction: gameStateManager.dishTimeFraction)
    }

    /// Reads the latest swipe from HandPoseManager and forwards it to
    /// the state machine. If it was a successful serve, captures the
    /// direction so the scene can animate the plate sliding out.
    func consumeSwipe() {
        guard let handPoseManager, let gameStateManager,
              let direction = handPoseManager.lastSwipe else { return }
        handPoseManager.clearSwipe()
        let wasServing = gameStateManager.state == .waitingForSwipe
        gameStateManager.handleSwipe(direction)
        if wasServing, gameStateManager.state == .cooking {
            lastServeDirection = direction
        }
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
            swipeCueNode?.removeFromParent()
            swipeCueNode = nil
            if let direction = lastServeDirection {
                lastServeDirection = nil
                animateServe(direction: direction, then: gameStateManager.currentRecipe)
            } else {
                finishedDishNode?.removeFromParent()
                finishedDishNode = nil
                spawnIngredientsIfNeeded(for: gameStateManager.currentRecipe)
            }

        case .dishComplete:
            spawnedRecipeName = nil
            clearTableIngredientNodes()
            showFinishedDish(gameStateManager.currentRecipe)

        case .waitingForSwipe:
            if let direction = gameStateManager.swipeCueDirection {
                showSwipeCue(direction: direction)
            }

        case .gameOver:
            break
        }
    }
}
