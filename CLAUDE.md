# GetCooking (aka VisionChef)

A hand-tracking cooking game for iOS/iPadOS (also runs iOS-on-Mac / Catalyst).
The front camera fills the screen, Vision tracks your hands in real time, and
you grab floating ingredient bubbles with a fist, drag them onto a plate, and
swipe left/right to serve once the plate matches the on-screen recipe.

Product name in code is inconsistent on purpose-ish: the Xcode target/module
is `GetCooking`, but several file headers and the app's `@main` struct still
say `VisionChef` (`VisionChefApp.swift`) — same app, leftover naming from an
earlier pass. Don't "fix" this without checking both names aren't relied on
elsewhere (bundle id, scheme).

## Stack

- Swift + SwiftUI + SpriteKit + AVFoundation + Vision (`VNDetectHumanHandPoseRequest`)
- No third-party dependencies, no SPM packages
- iOS/iPadOS only (`TARGETED_DEVICE_FAMILY = "1,2"`, `SDKROOT = iphoneos`),
  deployment target 26.5. Also has an explicit Mac code path
  (`ProcessInfo.isiOSAppOnMac` / `isMacCatalystApp`) since a Mac has no
  device-orientation rotation coordinator.
- Tests use the new Swift `Testing` framework (`import Testing`, `@Test`), not XCTest,
  except the two UI test files which are stock XCTest scaffolding.

## Architecture: 3-layer stack

Assembled in `Views/ContentView.swift`, back to front:

1. **Camera layer** — `Views/Camera/CameraPreviewView.swift`. Renders the live
   front-camera feed via `AVCaptureVideoPreviewLayer`. Reuses
   `HandPoseManager`'s existing `AVCaptureSession` rather than opening its own
   — iOS only allows one session per camera.
2. **Game layer** — `Scenes/GameScene/GameScene.swift`, a transparent
   `SpriteKit` scene (`.allowsTransparency`) drawn on top. Owns all physical
   interaction: ingredient bubbles, plate, trash bin, grab/drag/release,
   animations.
3. **HUD layer** — plain SwiftUI overlay: recipe card, score/timer badges,
   pause button, game-over card, camera-permission-denied card.

Two `ObservableObject`s live above all three layers, owned by `ContentView`
as `@StateObject`, and injected down into the scene:

- **`HandPoseManager`** (`Managers/HandPoseManager.swift`) — owns the camera
  session and all Vision inference.
- **`GameStateManager`** (`Managers/GameStateManager.swift`) — the game's
  state machine (recipe, plate contents, score, clock).

`GameScene` polls both every frame in `update(_:)`; it does not use Combine
subscriptions for its per-frame logic, just reads `@Published` values
directly since SpriteKit's loop already runs every frame.

## Folder map

```
GetCooking/
  App/                  App entry point + color theme
    VisionChefApp.swift     @main struct, just wraps ContentView
    AppTheme.swift           doc comment only — colors live in Assets.xcassets
                              as named color sets (Color.appText etc, Xcode-synthesized)

  Models/                Plain data, no logic beyond simple computed props
    Ingredient.swift        7-case enum: cheese/chicken/chili/cucumber/lettuce/mayonnaise/tomato
    Recipe.swift             struct + 4 static recipes + Recipe.all
    GameArt.swift            string constants for non-ingredient art (bubble, plate)

  Managers/              The "brains" — no UI code
    GameStateManager.swift   state machine: idle → cooking → dishComplete →
                              waitingForSwipe → gameOver → (restart) → cooking
    HandPoseManager.swift    AVFoundation capture + Vision hand-pose inference,
                              runs on a background queue, publishes HandData[]
    Enums/
      HandData.swift          one tracked hand, published to UI + scene
      SwipeDirection.swift     .left / .right

  Scenes/                SpriteKit game layer, split by concern
    GameScene/
      GameScene.swift          class decl, stored properties, update() loop,
                                state-machine sync (syncWithGameState)
      Input.swift               hand tracking → grab/drag/release/clap (extension)
      Layout.swift              plate + trash bin creation/positioning (extension)
      Spawning.swift            ingredient bubble spawning + scatter placement (extension)
      Serving.swift             finished-dish display, swipe cue, serve animation,
                                 plate commit/release/discard (extension)
    Components/
      IngredientNode.swift      SKNode: food sprite + bubble overlay sprite
    HoverDetector.swift         standalone dwell-timer gesture detector, used
                                 for "hold a hand over the bin to dump the
                                 plate" (kept out of GameScene so it's
                                 unit-testable without a live SpriteKit view)

  Support/               Small stateless helpers
    CGPoint+Distance.swift   vc_distance / vc_clamped (vc_ prefix avoids
                              colliding with other distance(to:) extensions)
    TrimmedArt.swift          crops PNGs to their opaque bounding box + caches
                              UIImage/SKTexture by name (source art is padded
                              on 1920×1080 canvases)

  Views/                 SwiftUI
    ContentView.swift        assembles the 3 layers, owns both managers
    Camera/CameraPreviewView.swift
    Components/
      HandSkeletonView.swift   debug overlay: draws bones + joints per hand
      PauseButton.swift
    GameOverlay/
      RecipeCardView.swift
      StatBadge.swift
      GameOverCard.swift
      CameraPermissionDeniedOverlay.swift

  Resources/
    Assets.xcassets/         named colors + ingredient/dish art (imagesets)
    *.png                     loose copies of the same art outside the asset
                               catalog (currently unused by code — TrimmedArt
                               reads via Assets.xcassets by name)

GetCookingTests/          Swift Testing unit tests (see Known issues below)
GetCookingUITests/        stock XCTest UI-test scaffolding, unmodified
```

## Game state machine (`GameStateManager`)

```
idle --start()--> cooking --(plate matches recipe)--> dishComplete
                     ^                                      |
                     |                              (0.9s reveal beat)
                     |                                      v
              (serve animation)                    waitingForSwipe
                     |                                      |
                     +-------- handleSwipe(correct dir) ----+
                     |
              discardPlate() (clap gesture, keeps same recipe/score)

any state --timer hits 0--> gameOver --restart()--> cooking (fresh recipe/score/clock)
```

- `resetToken` / `discardToken` are counters, bumped on `restart()` /
  `discardPlate()`. `GameScene` watches the *tokens*, not just `state`,
  because restarting can land on the same state and same recipe as before —
  comparing state alone was the "Play Again does nothing" bug.
- `matches(plateContents:recipe:)` is a multiset comparison (groups both
  arrays by value, compares counts) — order-independent, but no missing
  pieces and no extras allowed.

## Hand tracking pipeline (`HandPoseManager`)

1. Camera session picks the **widest** available format on the front camera
   (`widestCamera`, `selectWidestFormat`, `ranking`) and disables Center
   Stage — the game needs both hands + torso in frame, which default
   framing crops out.
2. Every frame, `VNDetectHumanHandPoseRequest` runs on `videoQueue`
   (background). `classify()` turns raw joints into palm centre + extended
   finger count + skeleton.
3. `extendedFingerCount` — a finger counts as extended when its tip is
   ≥1.5 *palm lengths* from the wrist. Scale-free (works at any distance
   from camera) — this is why it's ratio-based, not point-based.
4. `matchToTrackedHands` / `matchAssignments` — greedy nearest-neighbour
   identity tracking, because Vision returns hand observations in no
   guaranteed order. Without this, two hands could swap whichever bubble
   each was holding.
5. `detectSwipe` / `swipeDirection` — needs both minimum speed AND minimum
   net distance over a 0.3s window, and must be dominantly horizontal.
   Deliberately ignores hand pose (open/fist) during a swipe, since motion
   blur breaks pose classification exactly when a fast flick happens.
6. `viewPoint(fromNormalized:...)` — maps Vision's normalized
   (bottom-left-origin) coordinates to on-screen view space, undoing
   whatever `.resizeAspect`/`.resizeAspectFill` cropping the preview layer
   applies. Both the camera preview and the hand cursor read the same
   `previewGravity` property so they can never disagree. This is the most
   heavily unit-tested function in the project.

All tuning knobs (thresholds, smoothing, cooldowns) are `var`s at the top of
`HandPoseManager`, not constants — they're meant to be hand-tuned per device/
lighting, not treated as fixed.

## Known issues

- `Resources/*.png` (loose files, e.g. `Resources/Cheese.png`) duplicate what's
  already in `Assets.xcassets/*.imageset/` and don't appear to be read by any
  code — `TrimmedArt` always loads by name via `UIImage(named:)`, which reads
  the asset catalog. Worth confirming before deleting.

## Conventions worth knowing before editing

- `GameScene` is one class split across five files by concern
  (`GameScene.swift` + `Input.swift`/`Layout.swift`/`Spawning.swift`/
  `Serving.swift` as extensions) — mirrors the pattern in
  `GameStateManager`/`HandPoseManager` where the state machine and the
  hand-math live in one file each, not spread thin.
- Anything gnarly (coordinate mapping, finger-extension ratio, swipe
  detection, hover dwell) is pulled out as a `static func` or a standalone
  struct (`HoverDetector`) specifically so it's unit-testable without
  spinning up SpriteKit/AVFoundation/Vision.
- `#expect` expands its argument into a closure that captures immutably, so
  a `mutating` call has to be hoisted into a `let` before the macro — see
  `HoverDetectorTests`.
- An asset's lookup name is its **imageset folder name**, not the PNG inside
  it (`Contents.json`'s `filename` points at the PNG independently), and
  catalog lookups are **case-sensitive** even though macOS's filesystem is
  not. `ArtAssetTests.everyReferencedAssetExists` walks every
  `Ingredient.imageName` and `Recipe.finishedDishImageName` to catch drift —
  three assets had already silently gone blank this way.
- Distance/clamp helpers are prefixed `vc_` (`CGPoint.vc_distance`,
  `CGFloat.vc_clamped`) to avoid colliding with other `distance(to:)`
  extensions in scope (there's a second, private one inside
  `HandPoseManager` itself).
- Comments in this codebase explain *why*, not *what* — matches the
  project's own style; keep that pattern when adding new code/comments.
