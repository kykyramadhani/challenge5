# PlayFeat

A hand-tracking cooking game made with and for the community at PUSPADI
(Pusat Pemberdayaan Penyandang Disabilitas), Bali — Apple Developer Academy
Challenge 5 & Final Challenge.

The front camera fills the screen and Vision tracks the player's hands and
upper body. Players pinch floating ingredient bubbles, drag them onto a plate
to match the recipe, then carry the finished dish to the bell. No touch input
is needed during play.

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

### Game flow

```
Launch screen → Splash → Onboarding (first launch only) → Game Opening (main menu)
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

### Kitchen roles (v2 playtest)

The app now opens on `TitleScreenView` → `RoleSelectView` → `ProcurementView`
`ChefView` or `FrontHouseView` (`AppScreen.title` / `.roleSelect` /
`.procurement` / `.chef` / `.frontHouse`). The old main menu and sandwich game
above are still in the code but no longer reached from launch.

Shared by every role:

- `KitchenShift` (Game/Kitchen/): `OrderQueue` (4 orders, leftmost active,
  60 s each), the play clock, lives, served count. Each role's game owns one.
  When the active order is done depends on `KitchenMode`: `.playtest` (what
  ships now) completes it the moment every requirement is delivered;
  `.multiplayer` keeps it active until Front House serves it — syncing that
  across the three roles' iPads is still to do (see the multiplayer plan).
- `KitchenShiftView` (UI/Screens/): camera, then `ShiftPhase`: the seat
  check (`SeatCalibrationView`, every shift — whoever passes is locked in as
  the player with `lockOntoPlayer()`, released when the shift ends; skipped on
  the simulator and with `-debugGameplay`), then 3-2-1 (`ShiftCountdown`: the
  clock waits for the count to end *and* `HandPoseManager.isReceivingFrames`,
  holding on 1 if needed), order rail, shift clock, a zoomed-in panel, the
  SpriteKit layer, game over.
- `KitchenScene` (Scenes/KitchenScene/): hand glow and GameScene's
  grab/carry/release rules; each role subclasses it to say what can be picked
  up and where it can go. `KitchenLayout` maps Figma rects (1376×1034) to the
  screen; SwiftUI draws from each role's layout and the scene hit-tests the
  same rects. On the simulator a finger stands in for a hand
  (`-debugGameplay YES`, plus `-debugRole chef` or `-debugRole frontHouse`).
- `KitchenOrder.random` deals one dish per tray compartment (`TrayCompartment`:
  vegetable, dessert, soup, main — top-left to bottom-right) and maybe a drink, so every role's order
  fits Front House's tray. Its `stage` (waiting → eating → finishedEating) is
  the customer's side; the active order is the leftmost waiting one, and only
  it is on the clock.
- Routing follows `Preparation`: mushroom is chopped by Procurement, then
  sent to Front House; coral lettuce (`.soup`), bubble tuber (`.boil`) and
  tentacle (`.fry`) go raw to the Chef, who cooks them and sends them to Front
  House; star jelly (dessert) goes straight to Front House. A correct delivery
  ticks one open requirement on the active order at once.
- `HandIdentityTracker` gives every hand a stable ID and an anatomical
  `side` (chirality + body-wrist votes, never screen x), coasts missed hands
  on a bounded prediction (`isPredicted`, falling `trackingConfidence`) and
  recovers a returning hand's ID. Predicted or unidentified hands are drawn
  but must never trigger gameplay. `-debugTracking YES` shows the overlay.
- Kitchen art is in `Assets.xcassets/Kitchen`, exported from Figma.

Procurement (`ProcurementGame`, `ProcurementScene`):

- The 3 ingredient cards (`IngredientCardPicker`: 2 for the active order, 1
  for a later one, only the used card is re-dealt), cutting, washing, trays.
  Every portal goes through `ProcurementGame.delivery(of:sliced:to:)`.
- `KitchenCrew` is a timed stand-in for Chef and Front House, not AI.
- Chopping is `ChopDetector` (Vision/Gestures/): one chop per real swap
  between left-up/right-down and left-down/right-up across the board's
  middle, with a dead band; scrubbing is the GestureLab `MotionRecognizer`
  (open hands circling).

Chef (`ChefGame`, `ChefScene`):

- 5 floating raw bubbles (`ChefBubblePicker`): one per dish still needed,
  the active order's first, then the next orders'; a used bubble is replaced
  in its own slot and flies in from the Procurement portal.
- `CookingPot` per station: the boiling pot (tuber) and fryer (tentacle)
  cook by themselves; coral lettuce in the broth pot opens `SoupPanel` and
  only becomes soup through `StirGesture` (pinched hands circling — the
  opposite of washing's open hands). The finished dish floats over its pot
  until carried through the Front House portal (`ChefGame.delivery(of:)`).
- Playtest stand-in for Procurement: mushroom and star jelly requirements are
  ticked off as soon as their order becomes active.

Front House (`FrontHouseGame`, `FrontHouseScene`):

- 5 floating finished dishes (`BubbleRack`), arriving from the Chef portal
  (left) or the Procurement portal (right); clean trays on the stand, counted
  by the shared `KitchenCrew.cleanTrays`.
- A clean tray set on the counter becomes the `ServingTray`; each dish only
  fits its own compartment, and only if the active order wants it. A drink is
  poured at the dispenser (`DispenserPanel`, `LeverGesture`: pinch, pull left
  to open, push right to close once full).
- The complete tray carried onto the active ticket serves it: the order keeps
  its place on the rail, `.eating` for `eatTime` (3 s, tray on the green
  table), then `.finishedEating` (dirty tray there). The next waiting order
  is active at once (`OrderQueue.activeIndex`). Nothing new is dealt until
  the dirty tray goes through the Procurement portal; then the order is
  complete, the rail slides left and a new order arrives at the end, in both
  modes. At most `tableSeats` (2) trays on the table. The playtest stand-in
  washes returned trays and sends them back clean after `washTime`.

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
- No `snake_case`, no Hungarian notation, no type prefixes.
- Shared point and number maths (`distance(to:)`, `eased(toward:by:)`,
  `clamped(to:)`) lives in `Shared/Extensions/CGPoint+Distance.swift` and is
  `nonisolated`, so the Vision pipeline can use it too. Use it instead of
  writing another `hypot` or `min(max())`.
- One main type per file, and the file is named after it. Extensions that split
  a type by concern go in a folder named after the type
  (`Scenes/GameScene/Input.swift`).
- Header for new files:
  ```swift
  //
  //  FileName.swift
  //  PlayFeat
  //  Created by <Name> on <Current Date>.
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
- Two-part start: iOS shows `PlayFeat/Resources/Launch Screen.storyboard` while
  the app loads, then `SplashScreenView` plays the animated mascot. The launch
  screen is only the plain `SplashBackground` color — the splash's first frame —
  so the handover has no visible seam. Don't add the mascot or text to it: the
  splash fades them in from nothing, and launch screens can't use Atkinson.
- Because `project.pbxproj` is gitignored, anything only the project file knows
  about never reaches a teammate's clone. So the launch screen is wired through
  tracked files: the storyboard lives inside the synchronized `PlayFeat/` folder
  (bundled automatically), and `UILaunchStoryboardName` is in
  `PlayFeat/Info.plist`. Keep both there even if Xcode's target settings also
  set them. iOS caches launch screens: delete the app (or reset the simulator)
  to see a change.
- `#expect` captures its argument immutably. Move a `mutating` call into a
  `let` before the macro (see `HoverDetectorTests`).
- Vision runs on a background video queue. Anything it publishes must be sent
  to the main thread.
- **No GPU work outside the foreground.** iOS rejects it
  (`kIOGPUCommandBufferCallbackErrorBackgroundExecutionNotPermitted`). Vision
  and SpriteKit both use the GPU, so leaving `.active` is handled in two places:
  - `PlayFeatApp` (app-wide): `.inactive` → `HandPoseManager.suspend()` drops
    frames before Vision and stops the camera; `.background` also fades the
    music out. `.active` resumes both (the camera only if a screen still
    wants it).
  - `GameplayView` (per run): pauses the clock and `SpriteView` at `.inactive`
    too, since hand tracking is already off. A brief `.inactive` resumes at
    once; returning from `.background` plays a 3-2-1 first. A run killed by
    iOS while in the background is lost (no mid-run save).
  - `scenePhase` is forwarded explicitly into `ContentView`, because
    `PhoneSafeSides` hosts the app in its own hosting controller.

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

## Reference
`CODE_AUDIT.md` lists known bugs and tech debt found in an earlier audit.

## Planned: multiplayer (two-iPad co-op)

The full design, message list, open questions and step order are in
[`docs/multiplayer-plan.md`](docs/multiplayer-plan.md). Read it before starting
any multiplayer work, and keep it up to date as decisions are made.
