# Multiplayer plan: two-iPad co-op

Status: **planned, not started.** This file is the design to build from. Update
it whenever a decision below is made or changed.

## The mode

- **Players:** two, each on their **own iPad**, connected online.
- **Co-op, one shared kitchen:** one recipe, one plate, one bell, one reset button,
  **shared lives and shared score**.
- **Either player can do anything:** grab any ingredient, drop it on the plate,
  reset the plate, or carry the finished dish to the bell.
- Both screens show the same board. Each player sees their own hands as today and
  their partner's hands as "ghost" glows in a second colour.

### What does *not* change

Each iPad still tracks **only its own player**, using the existing
single-player Vision pipeline:

- `HandFrameProcessor`
- the nearest-body and bystander filter in `HumanBodyPoseManager`
- `HandInputMode` (one-hand / two-hand)
- the seat check

None of the "single player" assumptions in `Vision/` need to change for this
mode. Only **game state** and **hand cursors** cross the network.

## Architecture

```
 iPad A (host)                                   iPad B (guest)
 ┌──────────────────────────┐                    ┌──────────────────────────┐
 │ Camera → Vision → hands  │                    │ Camera → Vision → hands  │
 │            │             │                    │            │             │
 │ GameScene ◀┤             │   requests ◀────── │ GameScene ◀┤             │
 │    ▲       ▼             │                    │    ▲       ▼             │
 │ LocalGameSession         │   events,  ──────▶ │ RemoteGameSession        │
 │ (real GameStateManager)  │   snapshots,       │ (mirror of host state)   │
 │                          │   cursors          │                          │
 └──────────────────────────┘  ◀─ MatchTransport ─▶ └──────────────────────┘
```

### Transport

- **Game Center real-time match:** `GKMatchmakerViewController` to invite a friend
  or auto-match, then `GKMatch` to send data.
- The app already signs in to Game Center (`Network/GameCenter.swift`) and has the
  entitlement.
- All networking sits behind a small protocol, so the game never talks to GameKit
  directly:

  ```swift
  protocol MatchTransport: AnyObject {
      var role: MatchRole { get }            // .host or .guest
      func send(_ message: MatchMessage, reliably: Bool)
      var onReceive: ((MatchMessage) -> Void)? { get set }
      var onPartnerLeft: (() -> Void)? { get set }
  }
  ```

  It has three implementations:
  1. `GameKitTransport` for the real thing.
  2. `LoopbackTransport`, which joins two sessions in memory for unit tests.
  3. Later, if needed, `MultipeerTransport` for same-room play without internet.

### Host-authoritative rules

- One device is the **host**, chosen with `GKMatch.chooseBestHostingPlayer`, or the
  lower player ID as a fallback.
- The host runs the real `GameStateManager`: phases, clocks, recipe deck, lives,
  `RunTally`, `Difficulty`.
- The guest never changes game state itself. It sends **requests**, and the host
  applies them through the normal `GameStateManager` methods (`addIngredientToPlate`,
  `discardPlate`, `serveDish`, …) and broadcasts the result.
- This keeps a single source of truth, so the two screens can't disagree about lives
  or score.

### The `GameSession` seam (main refactor, do this first)

Today `GameScene` and the HUD read the concrete `GameStateManager`. Put a protocol
between them:

```swift
protocol GameSession: AnyObject {
    var state: GameState { get }
    var currentRecipe: Recipe { get }
    var plateContents: [Ingredient] { get }
    var lives: Int { get }
    var startingLives: Int { get }
    var dishesCompleted: Int { get }
    var events: GameEventLog { get }
    var dishTimeFraction: CGFloat { get }
    var serveTimeFraction: CGFloat { get }
    var hasWrongIngredient: Bool { get }

    func addIngredientToPlate(_ ingredient: Ingredient)
    func discardPlate()
    func serveDish()
}
```

There are two implementations:

- **`LocalGameSession`** wraps `GameStateManager`. Solo play and the host both use it.
- **`RemoteGameSession`** is used by the guest. It applies host events and snapshots,
  and turns the command methods into requests to the host.

These read `GameStateManager` directly today and would switch to `GameSession`:
- `GameScene` (and its `Input` / `Serving` extensions)
- `RecipeCard`
- `LoseHeartOverlay`
- `GameplayView`

`PointCard` and `HeartCard` already take plain values, so they need no change.

### Shared board coordinates

Two iPads can have different screen sizes, so nothing is sent in points. Board
positions travel as **normalized 0…1 coordinates** of the scene and are converted on
each side. This covers:

- ingredient spawn points
- held-item positions
- the plate position while carried
- partner cursors

### Hand ownership

The scene keys everything by a bare hand ID today:

- `IngredientNode.heldBy: Int?`
- `GameScene.plateHeldBy: Int?`
- `trackers: [Int: HandTracker]`
- `cursorNodes: [Int: HandGlowNode]`

Remote hand IDs would collide with local ones, so these become
`HandOwner(player: MatchRole, handID: Int)`.

Grabs are arbitrated by the host:

1. The guest sends `grab(ingredientID)`.
2. The host grants it if the item is free, and broadcasts `grabbed(ingredientID, by:)`.
3. If both players reach for the same bubble, the host's first-come answer wins, and
   the losing side releases.

Every spawned ingredient therefore needs a stable `ingredientID`, assigned by the
host when the recipe is dealt.

## Messages

All are `Codable` structs in `Network/Multiplayer/`.

| Kind | Direction | Channel | Examples |
|---|---|---|---|
| Lobby | both | reliable | `ready`, `startRun(at:)` (shared start time for the countdown) |
| Game events | host → guest | reliable | `recipeDealt(recipe, spawns:[id, point])`, `ingredientCommitted(id)`, `plateDiscarded`, `dishComplete`, `bellRang(side)`, `dishServed`, `lifeLost(livesLeft)`, `gameOver(result)` |
| Requests | guest → host | reliable | `grab(id)`, `release(id, at:)`, `commitToPlate(id)`, `discardPlate`, `pickUpPlate`, `serve` |
| Live motion | both | unreliable, ~15–20 Hz | hand cursors `[(handID, point, isOpen)]`, held item / carried plate position |
| Clock sync | host → guest | unreliable, ~5 Hz | host play-clock time, dish/serve countdown start + duration |

The guest's `RecipeCard` ring and tray timer are drawn from the clock-sync values,
so they stay in step with the host without sending every tick.

## Flow

1. **Main menu** gets a second button, **"Play Together"**. It opens a new
   `AppScreen.lobby`, which hosts the Game Center matchmaking / invite UI. With
   the `switch`-based navigation this is one extra case.
2. Once matched, each player does **their own** tutorial (first time only) and
   **their own** seat check, on their own iPad.
3. A "Waiting for your partner…" overlay shows until both have sent `ready`.
4. The host sends `startRun(at:)`. Both play the 3-2-1-GO countdown against that
   shared time.
5. **Play.** The partner's hands appear as ghost glows: `HandGlowNode` gets a
   per-player tint from the asset catalog.
6. **Game over** on both devices → `PostGameView` shows the team result.

## Edge cases to design

- **Partner disconnects mid-run:**
  - Pause both clocks and show a "Your partner left" overlay.
  - Offer "Keep playing solo" (the host carries on with `LocalGameSession`) or
    "End run".
  - A guest whose host left can only end the run.
- **Host migration:** out of scope at first. If the host leaves, the run ends for
  the guest.
- **Pause:** shared. Either player pausing pauses both.
- **Latency:**
  - A grab highlights immediately on the requesting device (optimistic), but only
    counts once the host confirms it.
  - Remote cursors are interpolated between updates so they don't jitter.
- **Backgrounding** (home button, incoming call): treated like a temporary
  disconnect, with a short grace period before "partner left".
- **One-hand mode:** stays a per-device setting. Each player picks their own.

## Open questions for the team

1. **Coins:** does each player get the full team payout, or half? Is a coin
   multiplier per device or shared?
2. **Leaderboard:** a separate "Most Dishes Served (Co-op)" Game Center leaderboard,
   or none for co-op?
3. **Connectivity at Puspandi:** is the internet reliable enough for Game Center
   matches, or should same-room play (`MultipeerConnectivity`, no internet) come
   first? The `MatchTransport` protocol allows either.
4. **Difficulty:** should two players face a faster ramp or shorter dish clocks than
   one?
5. **Tutorial:** do we need a short co-op page ("you share one plate and one set of
   hearts")?

## Build order

Use one branch per step, as in CLAUDE.md, and run ⌘U before and after each one.

1. `refactor/game-session`: add the `GameSession` protocol and
   `LocalGameSession`, and switch the scene and HUD to it. No behaviour change.
2. `refactor/board-coordinates`: normalized board coordinates, stable
   ingredient IDs, and `HandOwner` keys in the scene. No behaviour change.
3. `feature/match-messages`: the `MatchMessage` types, `MatchTransport`,
   `LoopbackTransport` and `RemoteGameSession`. Unit tests drive a full co-op
   round through the loopback (host and guest sessions with no network).
4. `feature/gamekit-lobby`: `GameKitTransport`, the `AppScreen.lobby` screen,
   the "Play Together" button, the ready/start handshake, and new strings in
   `Localizable.xcstrings` with Indonesian translations (plus the
   `LocalizationTests` key list).
5. `feature/coop-hands`: partner ghost glows, host-arbitrated grabs and plate
   carrying.
6. `feature/coop-polish`: disconnect handling, shared pause, team results, and the
   leaderboard decision.

## Testing

- **Unit:** run everything through `LoopbackTransport`, with no network or
  camera. `ScriptedHandInput` drives hands, and `SoundRecorder` checks
  sounds.
- **Manual:** two iPads signed in to **different Game Center sandbox accounts**.
  Check:
  - invite
  - both seat checks
  - synchronized countdown
  - both players grabbing the same bubble
  - carrying the plate to the bell
  - losing a life
  - a disconnect mid-run
