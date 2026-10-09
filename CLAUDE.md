# PlayFeat

A hand-tracking cooking game made with and for the community at Puspandi
(Pusat Pemberdayaan Penyandang Disabilitas), Bali — Apple Developer Academy
Challenge 5 & Final Challenge.

The front camera fills the screen and Vision tracks the player's hands and
upper body. Players pinch floating ingredient bubbles, drag them onto a plate
to match the recipe, then carry the finished dish to the bell. No touch input
is needed during play.

The project started as an app and is now a game. The codebase is being
refactored to match — see **Current development phase**.

## Platforms

| Platform | Status |
|---|---|
| iPadOS | **Published** — the only shipping target right now |
| iOS (iPhone) | Planned. Layouts already scale, but it isn't released or fully tested |
| macOS | Planned. Some Mac code paths exist (`ProcessInfo.isiOSAppOnMac`), not shipped |

- **Minimum OS: iOS / iPadOS 17.0.** Don't use APIs newer than 17 without an
  `if #available` check and a fallback.
- Landscape lock (left and right), portrait is still being used but added hints unavailable, because of the new requirement of iOS 27.
- Languages: English (`en`) and Indonesian (`id`), in `Localizable.xcstrings`.

## Capabilities in use

- **Camera** — front camera through AVFoundation (`NSCameraUsageDescription`).
  Picks the widest format and turns off Center Stage so both hands and the
  torso stay in frame.
- **Vision** — `VNDetectHumanHandPoseRequest` (hands) and
  `VNDetectHumanBodyPoseRequest` (finds the nearest player, ignores bystanders).
- **SpriteKit** — the transparent game board drawn over the camera feed.
- **SwiftUI** — every screen, overlay and HUD element.
- **Game Center** — sign-in and the "Most Dishes Served" leaderboard
  (`com.apple.developer.game-center` entitlement). Always optional: the game
  works fully offline or signed out.
- **SwiftData + UserDefaults** — inventory (SwiftData); coins, high score and
  settings (UserDefaults / `@AppStorage`).
- **AVAudio** — music and sound effects.
- **Accessibility** — Atkinson Hyperlegible font, one-hand mode in Settings.

No third-party dependencies and no SPM packages.

## Game flow

### App flow

```
Splash → Onboarding (first launch only) → Game Opening (main menu)
                                              │ Tap to Play
                                              ▼
                     Tutorial (until finished or skipped)
                                              ▼
                     Seat calibration (head, shoulders and hands inside the guide box)
                                              ▼
                     3-2-1-GO! countdown → Gameplay
                                              ▼ last life lost
                     Game Over → Post Game (paycheck: dishes, speed bonus, coins)
                                              │ Play Again / Home
                                              ▼
                     Gameplay again or Game Opening
```

- `SceneManager` (App/) holds the current `AppScreen` (`mainMenu`, `shop`,
  `gameplay`, `postGame(GameResult)`); `ContentView` switches on it. There is
  no `NavigationStack`: no screen has a back button, and every exit jumps to a
  known screen. Tutorial, calibration and countdown are *phases inside*
  `GameplayView`, not separate screens. That keeps the camera mounted across
  the handover.
- Each run creates a fresh `GameStateManager`, so Play Again always starts clean.
- The Shop exists but is "coming soon".

### One round

1. A recipe card shows the dish and its ingredients, and the dish clock starts.
2. The player **pinches** (thumb and index finger) an ingredient bubble, drags
   it, and opens their fingers to drop it on the plate. Wrong ingredients count
   as decoys.
3. Holding a hand over the reset button empties the plate (dwell/hover gesture).
4. When the plate matches the recipe, the finished dish appears and the
   **bell rings on the left or right**. The player carries the plate to that side.
5. A served dish adds to the score and banks leftover clock time as a speed
   bonus. A dish that runs out of time **costs one life** and deals a new recipe.
6. Difficulty ramps every 5 served dishes. The run ends when lives reach 0.
   There is no overall timer; elapsed time counts up.

### Game state (`GameStateManager`, Game/)

```
idle ──start()──▶ cooking ──plate matches──▶ dishComplete ──bell rings──▶ waitingToServe
                    ▲                                                        │
                    └──────────────── plate carried to the bell ─────────────┘

dish clock runs out → lose a life, new recipe (resetToken)
lives reach 0       → gameOver ──restart()──▶ cooking
```

`resetToken`, `discardToken` and `runToken` are counters that tell the scene
and UI about events that don't change `state`. Read the doc comments in
`GameStateManager` before touching them.

## Architecture

Three layers, back to front, assembled in `GameplayView`:

1. **Camera layer** — `CameraPreviewView` shows the live feed. It reuses the
   capture session in `HandPoseManager` (only one session per camera).
2. **Game layer** — `GameScene`, a transparent SpriteKit scene. Owns all
   physical interaction: bubbles, plate, bell, grab/drag/release, animations.
3. **HUD layer** — SwiftUI overlays: recipe card, hearts, points, pause,
   countdown, game over, camera-permission card.

Data flows one way: **Vision → Game → Scene / UI**. `GameScene` reads hand data
and game state every frame in `update(_:)` (polling suits a 60 fps loop).
SwiftUI observes the same objects.

## Folder structure

```
PlayFeat/
├── App/        Entry point, root navigation and screen routing
├── Game/       Game rules and state: rounds, scoring, lives, clocks, difficulty.
│               No SwiftUI or SpriteKit here.
├── Vision/     Everything built on the Vision framework: hand and body pose
│   └── Gestures/  Gesture detectors built on pose data (pinch, hover, swipe)
├── Camera/     Camera permission, device and format selection, preview view
├── Audio/      Music and sound effects
├── Network/    Online services (Game Center)
├── Data/
│   ├── Models/   Plain data types (recipes, ingredients, shop items, ...)
│   └── Storage/  Saving and loading (UserDefaults, SwiftData)
├── Scenes/     Everything SpriteKit
│   ├── GameScene/  The game scene, split into extensions by concern
│   ├── Nodes/      Reusable SKNodes
│   └── Animation/  Sprite animations
├── UI/         Everything SwiftUI
│   ├── Screens/     Full-screen views (one per navigation destination)
│   ├── Overlays/    Views shown over gameplay
│   ├── Components/  Reusable building blocks (buttons, cards, ...)
│   └── Styles/      Button and view styles
├── Shared/     Small helpers used everywhere: extensions, layout scaling,
│               localization
└── Resources/  Assets, fonts, sounds, videos

PlayFeatTests/    Unit tests. Same folders as the app, so the tests for
                  Vision/ live in PlayFeatTests/Vision/
PlayFeatUITests/  UI tests (still starter scaffolding)
```

Put a new file in the folder whose job it matches. If it doesn't fit any of
them, ask before making a new top-level folder. Don't create folders grouped
by language construct (no `Enums/`, `Protocols/`, `Extensions/` at the top
level). Keep a type next to the feature that uses it.

All three targets use Xcode **synchronized folders**: moving or adding files on
disk needs no `project.pbxproj` edits.

## Clean code, style and conventions

**Every time you write or change code, follow the clean-code skill:**
@.claude/skills/clean-code/SKILL.md
Full checklist for larger changes and reviews:
@.claude/skills/clean-code/clean-code-rules.md

Summary:

- **Names explain intent.** Types are nouns (`RecipeCard`), functions are verbs
  (`serveDish()`). Avoid vague names like `data`, `info`, `helper`, `temp`.
- **Small functions that do one thing**, at one level of abstraction. Aim for
  under ~20 lines.
- **0–2 arguments**, 3 at most. Replace a Bool flag argument with two functions.
- **Commands vs. queries:** a function changes state *or* returns a value, not both.
- **Small types with one responsibility.** Find the type that owns new logic
  instead of adding it wherever is nearby.
- **Comments explain *why*, not *what*.** Rewrite confusing code rather than
  commenting it. Never commit commented-out code.
- **No force-unwraps (`!`) or silent failures.** Use optionals, `throws` and
  typed errors with context.
- **DRY, YAGNI, KISS, Boy Scout:** no duplication, nothing built for imagined
  needs, the simplest working solution, and leave each file cleaner.
- **Design patterns only when they remove a real problem**, not for show.

### Naming and formatting

- **camelCase** for variables, properties, functions and enum cases
  (`dishTimeFraction`, `case waitingToServe`).
- **UpperCamelCase** for types and protocols (`GameStateManager`, `HandInputSource`).
- No `snake_case`, no Hungarian notation, no type prefixes. The existing `vc_`
  helpers (`vc_distance`, `vc_clamped`) predate this rule; rename them when you
  touch them.
- One main type per file, and the file is named after it. Extensions that split
  a type by concern go in a folder named after the type
  (`Scenes/GameScene/Input.swift`).
- Header for new files:
  ```swift
  //
  //  FileName.swift
  //  PlayFeat
  //
  //  One or two lines on what this type is for and why it exists.
  //
  ```
- Lines under ~120 characters. Group code with `// MARK: -`.

### Swift and SwiftUI

- Use `let` and value types (`struct`, `enum`) by default.
- Use `@Observable` for new observable classes, not `ObservableObject` /
  `@Published`. Pass them with `@State` / `@Environment` / `@Bindable`.
- Don't add new singletons (`static let shared`). Create objects once in
  `PlayFeatApp` and inject them.
- Keep SwiftUI `body` small; extract subviews as soon as it gets hard to scan.
- Colors and fonts come from the asset catalog and `Font+Atkinson`; layout sizes
  come from `DesignScale`. No magic numbers repeated across files.
- Every user-facing string goes through `Localizable.xcstrings` with an
  Indonesian translation. `LocalizationTests` fails if one is missing.
- Pull tricky math (coordinate mapping, gesture timing, matching) into a
  `static func` or a small struct so it can be unit-tested without a camera
  or SpriteKit view.

### Project-specific gotchas

- An asset's lookup name is its **imageset folder name**, and lookups are
  **case-sensitive**. `ArtAssetTests` catches mismatches.
- `#expect` captures its argument immutably. Move a `mutating` call into a
  `let` before the macro (see `HoverDetectorTests`).
- Vision runs on a background video queue. Anything it publishes must be sent
  to the main thread.

## Testing

- **⌘U** runs all unit tests (Swift Testing: `import Testing`, `@Test`, `#expect`).
- Run the tests **before and after every refactor**. They should pass both
  times with no changes to the tests.
- New logic comes with tests in the matching `PlayFeatTests/` folder.
- Camera and Vision changes also need a manual check on a real iPad: pinch,
  drag, drop, hover reset, bell serve, rotation, one-hand mode.

## Git workflow

- **Never commit directly to `main`.** Every new feature or fix gets its own
  branch from an up-to-date `main`:
  - `feature/<short-name>`, e.g. `feature/shop-screen`
  - `fix/<short-name>`, e.g. `fix/bell-side-swap`
  - `refactor/<short-name>`, e.g. `refactor/observable-migration`
- **Commit messages have no fixed format, but must summarize the changes:**
  what changed and why, in plain words. One logical change per commit.
  - Good: `Move hand-tracking rules into OneHandMode / TwoHandMode strategies`
  - Bad: `update`, `fix stuff`, `wip`
- Run ⌘U before merging. Merge back into `main` through a pull request on GitHub.
- Claude: create or switch to the right branch **before** editing code, and
  commit or push only when asked.

## Current development phase

Refactoring from an "app" structure to a game structure (one branch or commit
per step, ⌘U before and after).

Done:

- Folder restructure, tests split by feature
- `ObservableObject` → `@Observable`
- Singletons replaced with dependency injection (`AudioManager`,
  `CameraManager`, `InventoryManager`); `ClickButton` plays the UI click
- Strategy pattern for input modes (`HandInputMode`: one-hand / two-hand)
- `GameState` cleanup: flags and tokens folded into states and events;
  `GameStateManager` split (`PlayClock`, `Difficulty`, `RecipeDeck`, ...)
- Protocols for gameplay dependencies: `GameScene` and `GameStateManager`
  depend on `HandInputSource` and `SoundPlaying`, not on `HandPoseManager` /
  `AudioManager`. Tests use `ScriptedHandInput` and `SoundRecorder`.
- Navigation: `NavigationStack` replaced by a `switch` over `AppScreen`;
  the unused `GameOption` / `GameCard` carousel removed

Next:

1. End-to-end gameplay test: a `ScriptedHandInput` hand carries an ingredient
   onto the plate in a real `GameScene`
2. Split `HandPoseManager` into camera session, Vision processing and gesture
   tracking
3. Move game-event sounds out of `GameStateManager` into a `GameAudio` that
   reacts to game events

`CODE_AUDIT.md` lists known bugs and tech debt found in an earlier audit.

## Planned: multiplayer (two-iPad co-op)

Not implemented yet. Two players, each on their own iPad, cook together in
**one shared kitchen** (one recipe, one plate, shared lives and score),
connected through a Game Center real-time match. Each iPad keeps tracking only
its own player with the existing single-player Vision pipeline; only game
state and hand cursors cross the network, and the host's `GameStateManager` is
the source of truth.

The full design, message list, open questions and step order are in
[`docs/multiplayer-plan.md`](docs/multiplayer-plan.md). Read it before starting
any multiplayer work, and keep it up to date as decisions are made.
