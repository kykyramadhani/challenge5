<p align="center">
  <img src="PlayFeat/Resources/Assets.xcassets/AppIcon.appiconset/image%201942.png" alt="PlayFeat! app icon" width="160">
</p>

<h1 align="center">PlayFeat!</h1>

<p align="center">
  A hand-tracking kitchen game for iPad. No touching the screen, just your hands.
</p>

<p align="center">
  Made with and for the community at <b>PUSPADI</b> (Pusat Pemberdayaan Penyandang Disabilitas), Bali<br>
  Apple Developer Academy · Challenge 5 &amp; Final Challenge
</p>

---

## Contents

- [About](#about)
- [The game](#the-game)
- [How you play with your hands](#how-you-play-with-your-hands)
- [Accessibility](#accessibility)
- [Tech stack](#tech-stack)
- [Architecture](#architecture)
- [Getting started](#getting-started)
- [Running on the simulator](#running-on-the-simulator)
- [Tests](#tests)
- [Contributing](#contributing)
- [Docs](#docs)
- [Team](#team)

## About

PlayFeat! turns the iPad's front camera into the controller. The camera feed
fills the screen, and Vision follows the player's hands and upper body in real
time. You pinch floating bubbles, carry them across the kitchen and serve
customers, all without touching the screen.

That matters for the people we built it with: players at PUSPADI who can't
easily use a touchscreen can still play, and one-hand mode lets players who
have one arm available play the whole game.

## The game

Three players run one space kitchen together. Each player has one role:

| Role | What you do |
|---|---|
| **Procurement** | Pick ingredients from the crates, chop mushrooms on the board, wash dirty trays in the sink, and send everything through a portal |
| **Chef** | Boil bubble tubers, fry tentacles and stir coral lettuce into soup, then send the cooked dishes to Front House |
| **Front House** | Put each order together on a food tray, pour drinks at the dispenser, serve the customers and send the dirty trays back |

Where each ingredient goes:

| Ingredient | Route |
|---|---|
| Mushroom | Chopped by Procurement, then sent to Front House |
| Coral lettuce | Raw to the Chef, stirred into soup, then to Front House |
| Bubble tuber | Raw to the Chef, boiled, then to Front House |
| Tentacle | Raw to the Chef, fried, then to Front House |
| Star jelly (dessert) | Straight to Front House |

### Rules of a shift

- The first order arrives right away. After that, a new order arrives
  **20 seconds** after the last one, as long as fewer than **3 orders** are
  waiting.
- Every order has its own **60-second clock** that starts when it arrives and
  never resets. You can work on any waiting order you like.
- An order that runs out of time leaves and **costs a heart**. With no hearts
  left, the shift ends straight away. You can also press **Stop**.
- Front House serves a full tray and its drink on the order's ticket. The
  customer eats, and the order is only finished once the dirty tray goes back
  through the Procurement portal.
- At the end, a **shift report** scores the work you did in your role.

> **Playtest build:** right now you play **one role per shift**, and the other
> two roles are timed stand-ins (`KitchenCrew`), not real players. Playing all
> three roles together on three iPads is planned, see
> [`docs/multiplayer-plan.md`](docs/multiplayer-plan.md).

## How you play with your hands

| Gesture | What it does |
|---|---|
| **Pinch** (thumb and index finger) | Pick up a bubble, card, dish or tray |
| **Move your hand** while pinching | Carry it |
| **Open your hand** | Let go. A bubble let go in empty space stays where you left it |
| **Touch a portal** while carrying | The item is sucked in right away, no need to let go |
| **Chop** (one hand up, one hand down, then swap) | Slice mushrooms on the board (Procurement) |
| **Open hands circling** | Scrub a dirty tray in the sink (Procurement) |
| **Pinched hands circling** | Stir coral lettuce into soup (Chef) |
| **Pinch the lever, pull left, push right** | Open and close the drink dispenser (Front House) |

Before every shift there is a **seat check**: your head, shoulders and hands
have to fit inside the guide box. The player who passes it is locked in, so
the game follows only you and ignores people walking behind you.

## Accessibility

- **No touch needed** during play. Everything is done with hand gestures.
- **One-hand mode** in Settings: pick your left or right hand, and only that
  hand is tracked and needed for the seat check.
- **Atkinson Hyperlegible** font everywhere, designed for low-vision readers.
- **English and Indonesian**, switchable inside the app.
- Played in **landscape**. If the window turns portrait, the game asks you to
  rotate the iPad instead of squeezing the layout.

## Tech stack

| | |
|---|---|
| Language | Swift |
| UI | **SwiftUI** for every screen, overlay and HUD |
| Game board | **SpriteKit**: a transparent scene drawn over the camera feed |
| Hand and body tracking | **Vision**: `VNDetectHumanHandPoseRequest` for hands and `VNDetectHumanBodyPoseRequest` to find the nearest player |
| Camera | **AVFoundation**: front camera, widest format, Center Stage turned off so both hands and the torso stay in frame |
| Audio | **AVAudio**: music and sound effects |
| Online | **Game Center**: optional sign-in and the "Most Dishes Served" leaderboard. The game works fully offline |
| Storage | **SwiftData** for the inventory, **UserDefaults** / `@AppStorage` for coins, high score and settings |
| Localization | English and Indonesian in `Localizable.xcstrings` |
| Tests | **Swift Testing** (`import Testing`, `@Test`, `#expect`) |

There are no third-party dependencies and no Swift packages.

### Platforms

| Platform | Status |
|---|---|
| iPadOS | **Published**, and the only shipping target right now |
| iOS (iPhone) | Planned. Layouts already scale, but it isn't released or fully tested |
| macOS | Planned |

The minimum OS is **iOS / iPadOS 17.0**.

## Architecture

The game is drawn in three layers, back to front:

1. **Camera**: the live front-camera feed.
2. **Game board**: a SpriteKit scene that handles every grab, carry and drop.
   Each role has its own scene on top of a shared `KitchenScene`.
3. **HUD**: SwiftUI overlays such as the order tickets, shift clock, hearts,
   panels and the game-over screen.

Data flows one way: **Vision → game rules → scene and UI**. The rules live in
plain Swift types with no SwiftUI or SpriteKit, so the unit tests can drive
them without a camera.

```
PlayFeat/
├── App/        Entry point and screen routing (SceneManager / AppScreen)
├── Game/       Game rules and state
│   └── Kitchen/   The three roles, order queue, shift clock and shift report
├── Vision/     Hand and body pose, player selection
│   ├── Gestures/    Gesture detectors (pinch, hover, chop, stir, lever, ...)
│   └── InputModes/  One-hand and two-hand modes
├── Camera/     Permission, device and format selection, preview
├── Audio/      Music and sound effects
├── Network/    Game Center
├── Data/
│   ├── Models/    Plain data types (recipes, ingredients, roles, ...)
│   └── Storage/   Saving and loading (UserDefaults, SwiftData)
├── Scenes/     SpriteKit: KitchenScene plus one scene per role
├── UI/         SwiftUI screens, overlays, components and styles
├── Shared/     Small helpers: extensions, layout scaling, localization
└── Resources/  Assets (art exported from Figma), fonts, sounds, videos

Testing/
├── PlayFeatTests/              Unit tests, in the same folders as the app
├── PlayFeatUITests/            UI tests
└── Functionality.xctestplan    Test plan
```

## Getting started

### Requirements

- A Mac with a recent **Xcode** (the team builds with Xcode 26 and 27)
- An **iPad** with a front camera for real hand tracking. The simulator works
  for layout and quick checks (see below)

### Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/kykyramadhani/challenge5.git
   cd challenge5
   ```
2. Get the Xcode project file. **`PlayFeat.xcodeproj/project.pbxproj` is not
   in the repository** (it is in `.gitignore`), so a fresh clone can't open in
   Xcode yet. Ask a team member for their copy and put it in
   `PlayFeat.xcodeproj/`.
3. Open `PlayFeat.xcodeproj` in Xcode.
4. Under **Signing & Capabilities**, choose your own team if you are not on
   the project's team.
5. Pick your iPad as the run destination and press **⌘R**.
6. Allow camera access when the game asks for it.

## Running on the simulator

The simulator has no front camera, so a **finger stands in for a hand**. These
launch arguments (Xcode: *Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸ Arguments*)
help you jump straight to what you want to check. They only work in Debug
builds:

| Argument | What it does |
|---|---|
| `-debugGameplay YES` | Skip onboarding, the tutorial and the seat check, and start a shift |
| `-debugRole chef` / `-debugRole frontHouse` | Pick the role for that shift (Procurement by default) |
| `-debugTracking YES` | Show the hand-tracking overlay |
| `-debugScreenSize 1133x744` | Lay the app out at any screen size, scaled to fit the real screen |
| `-debugRotateAfter 8` | Swap that size's width and height after 8 seconds, to test rotation |
| `-debugLandscape YES` | Turn an iPhone to landscape at launch |

## Tests

- Press **⌘U** in Xcode to run all the unit tests.
- Tests use **Swift Testing** and live in `Testing/PlayFeatTests/`, in the same
  folders as the code they test (tests for `PlayFeat/Vision/` are in
  `Testing/PlayFeatTests/Vision/`).
- Game rules, gestures and coordinate maths are plain Swift types, so they
  are tested without a camera or a SpriteKit view.
- Changes to the camera or Vision code also need a manual check on a real
  iPad: pinch, drag, drop, the role gestures, rotation and one-hand mode.

## Contributing

- **Never commit to `main`.** Branch off an up-to-date `main` with
  `feature/<short-name>`, `fix/<short-name>` or `refactor/<short-name>`, and
  merge back through a pull request on GitHub.
- Write commit messages that say what changed and why, in plain words.
- Run **⌘U** before you merge.
- Code style, conventions and project gotchas are in [`CLAUDE.md`](CLAUDE.md).
- Shared Claude skills live in [`.claude/skills/`](.claude/skills/):
  `clean-code` (how code is written and reviewed here), `new-screen` (how to
  add a screen with the shared styles) and `apple-hig` (Apple's Human
  Interface Guidelines).

## Docs

| File | What's in it |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | How the project is built, conventions and gotchas |
| [`docs/multiplayer-plan.md`](docs/multiplayer-plan.md) | The plan for playing on several iPads together |

## Team

Built at the **Apple Developer Academy** together with the community at
**PUSPADI**, Bali.

- Owen Limantoro
- Rizky Insania

See every contributor on the
[contributors page](https://github.com/kykyramadhani/challenge5/graphs/contributors).

Font: [Atkinson Hyperlegible](https://www.brailleinstitute.org/freefont/) by
the Braille Institute.
