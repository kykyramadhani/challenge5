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

    let grabSlack: CGFloat = 30

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
        consumeSwipe()
        syncWithGameState(force: false)
        updateHandInput(now: currentTime)
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
