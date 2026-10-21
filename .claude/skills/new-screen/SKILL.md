---
name: new-screen
description: Rules for adding any new SwiftUI screen, page, overlay, panel or component to PlayFeat — which folder it goes in, how it is wired into navigation, and the fixed set of colours, fonts, sizes, buttons and components it must reuse instead of inventing its own styling. Use it whenever you create or substantially rebuild a view, even if the user just says "make a page", "add a screen", "build this Figma frame", "new popup" or "new card".
---

# New screen / view

PlayFeat's look comes from a small, fixed toolkit — like a utility CSS
framework, where you compose existing classes instead of writing new CSS.
A new view **composes what exists**. It never invents its own colours, fonts,
button styles or one-off sizes. If something truly isn't there yet, add it to
the shared toolkit (below) so the next view can reuse it.

Read `CLAUDE.md` and follow the `clean-code` skill as well; this skill only
adds the rules specific to building views.

## 1. Before writing code

1. **Branch.** Create or switch to `feature/<short-name>` from an up-to-date
   `main` before editing (CLAUDE.md git workflow).
2. **Find the Figma frame.** Every number on screen comes from the design
   (1376 × 1034 canvas, or the 1366 × 1024 `DesignCanvas`). If there's no
   frame, ask rather than guess sizes.
3. **Look for an existing piece first.** Search `UI/Components/`,
   `UI/Overlays/` and `UI/Styles/` for something that already draws it (a
   card, a pill, a ticket, a progress bar, a tray). Extend or reuse it.

## 2. Where the file goes

| It is… | Folder | Example |
|---|---|---|
| A full-screen destination (has its own `AppScreen` case) | `UI/Screens/` | `RoleSelectView` |
| Drawn over gameplay (HUD, popup, panel, countdown) | `UI/Overlays/` | `GameHUD`, `StopButtonLayer` |
| A reusable building block used by 2+ views | `UI/Components/` | `RoleCard`, `TicketShape` |
| A button variant or shared view style | `UI/Styles/` (+ `UI/Components/Button/` for button views) | `ButtonComponentStyle` |
| Anything drawn by SpriteKit | `Scenes/` (never `UI/`) | `KitchenScene` subclasses |
| Layout rects for a kitchen role | next to that role's layout type, conforming to `KitchenLayout` | `ProcurementLayout` |
| Rules or state the view shows | `Game/` (no SwiftUI there) | `KitchenShift` |

- **One main type per file, named after it.** A private subview used only by
  this view may stay in the file; anything reused moves to `UI/Components/`.
- **No folders by language construct** (no `Views/`, `Enums/`, `Extensions/`
  at the top level). Ask before creating a new top-level folder.
- Tests mirror the app folders under `Testing/PlayFeatTests/`.

## 3. File header

```swift
//
//  FileName.swift
//  PlayFeat
//  Created by <Name> on <today's date>.
//
//  One or two lines on what this view is for and why it exists.
//
```

Never copy an old header that says GetCooking or VisionChef.

## 4. Wiring a new full-screen destination

1. Add a case to `App/AppScreen.swift` with a one-line doc comment.
2. Add a navigation method to `App/SceneManager.swift`
   (`func goToX()` / `func play(_:)`): one line that sets `screen`.
3. Add the `case` to the `switch` in `UI/Screens/ContentView.swift`, with
   `.transition(.opacity)` like the others.
4. Add a test to `Testing/PlayFeatTests/App/SceneManagerTests.swift` that the
   method lands on the new screen.

There is no `NavigationStack`: never add one, a back button bar, or
`.navigationDestination`. Exits call `SceneManager` methods.

## 5. The toolkit — use these, never your own

### Colours: asset catalog only
Use the Xcode-generated symbols for colorsets in
`Resources/Assets.xcassets` (and its `Kitchen/` folder):
`.appPrimary`, `.appSecondary`, `.appTertiary`, `.appAccent`, `.appText`,
`.appSecondaryText`, `.appTertiaryText`, `.appBackground`, `.splashBackground`,
`.kitchenElevated`, `.kitchenInk`, `.kitchenPurple`, `.kitchenPageTint`,
`.kitchenTrack`, `.kitchenCrate`, `.kitchenCrateLid`, `.ticketTimerGreen`,
`.playRolePink`, `.nebulaPink`, `.patternBlue`, `.trayStandPurple`, …
(`ls Resources/Assets.xcassets` for the full list).

- ❌ `Color(red:green:blue:)`, `Color(white:)`, hex values, `UIColor(named: "…")`
  strings, system colours (`.red`, `.blue`, `.gray`, `.accentColor`).
- ✅ Only `.black`/`.white` with `.opacity(…)` for scrims and shadows.
- **Need a new colour?** Add a colorset named for its *role*
  (`WarningRed`, not `Red2`), in `Kitchen/` if it's kitchen art, and use the
  generated symbol.

### Text: Atkinson only, localized
- Font: `.font(.atkinson(size: <Figma size>, weight: …))` — never
  `.font(.system…)`, `.custom(…)` or Dynamic Type text styles. Atkinson only
  ships Regular and Bold; `.heavy`/`.black` render as Bold.
- Size: the Figma value at canvas scale. The view must be inside
  `.designScaled()` or placed with `.placed(in:designSize:)` so it scales.
- Every user-facing string is a `LocalizedStringKey` in `Text("…")`, added to
  `Localizable.xcstrings` **with an Indonesian translation**, and to the key
  list in `LocalizationTests`. Outside a `Text` (SpriteKit labels, model
  strings) resolve it with `AppLocalization.string`. Numbers use
  `Text(verbatim:)`.
- Outlined title text: `.outlined(width:)` (`UI/Components/OutlinedText.swift`).

### Sizes and positions: design canvas, not the screen
- Full screens laid out on the canvas: build at canvas size and apply
  `.designScaled()` (see `RoleSelectView`, `TitleScreenView`).
- Kitchen screens: take rects from the role's `KitchenLayout`
  (`rect(x:y:width:height:_:)` with a `FigmaAnchor`, Figma numbers) and put
  views on them with
  `.placed(in: rect, designSize: CGSize(…))`. SwiftUI and the scene read the
  same rects, so never position kitchen furniture any other way.
- ❌ `UIScreen.main.bounds`, hard-coded device sizes, `GeometryReader`
  fractions invented for this view.
- A number used more than once is a named `private static let` with a
  comment; a number shared across files moves to `DesignCanvas` or the
  layout type.

### Buttons and taps
- Every tappable control is `ClickButton` (plays the UI click) or
  `ButtonComponent(name:icon:action:buttonStyle:)` for the standard capsule
  button, styled through `ButtonComponentStyle` (`.primary`, `.text`).
  Icon-only buttons: `BackButton`, `SettingsButton`.
- ❌ Plain `Button`, `.onTapGesture` on an image, or a new one-off button look.
  A new kind of button is a new `ButtonComponentStyle` case, not local styling.
- Gameplay itself is played with hands, not touch: touch controls only exist
  outside play or as hidden escapes (`StopButtonLayer`).

### Reusable pieces to check first
`BackgroundImage`, `OutlinedText`, `RoleCard`, `TicketShape`,
`PanelProgressBar`, `TrayArtView`, `TrayBubble`, `IngredientBubble`,
`IngredientArt`, `IngredientCrate`, `ServingTrayView`, `FloatingBubbles`,
`CirclePattern`, `TutorialBubble`, `PayCheckView`, `GameHUD`,
`StopButtonLayer` — all in `UI/Components/` or `UI/Overlays/`.

### Styling values without a shared token yet
Corner radii, card shadows and scrim opacities are still literals in each
view. Don't invent new values: copy the one used by the closest existing
component. The second time a value is needed in another file, promote it to a
shared constant instead of copying it again.

## 6. State, data and dependencies
- Shared objects (`AudioManager`, `HandPoseManager`, `InventoryManager`)
  arrive by `@Environment(Type.self)`; never create one inside a view and
  never add a singleton.
- New observable state is `@Observable` (not `ObservableObject`), owned by the
  view with `@State`, or by `Game/` if it's game rules.
- Keep `body` short: extract subviews as soon as it's hard to scan.
- Anything per-frame or SpriteKit-driven stays in the scene; the view only
  reads state.

## 7. Accessibility (the game is made with a disability community)
- Real buttons (`ClickButton`) so VoiceOver and Switch Control can find them.
- Icon-only controls get `.accessibilityLabel`.
- Decorative art gets `.accessibilityHidden(true)`.
- Looping motion respects `@Environment(\.accessibilityReduceMotion)`.

## 8. Preview
Every view ends with a `#Preview` that injects what it reads from the
environment, for example:

```swift
#Preview {
    RoleSelectView(onPlay: { _ in })
        .environment(AudioManager())
}
```

## 9. Before calling it done

Run this from the repo root and fix anything it prints **in your new or
changed files**:

```bash
grep -nE 'Color\(red:|Color\(white:|UIColor\(named:|\.font\(\.system|^\s*Button[ ({]|onTapGesture|NavigationStack|UIScreen\.main|GetCooking|VisionChef' <your files>
```

Then:
- [ ] File is in the right folder, named after its type, with the header.
- [ ] Only asset-catalog colours, `.atkinson` fonts, Figma sizes inside
      `.designScaled()` / `.placed(in:designSize:)`.
- [ ] Only `ClickButton` / `ButtonComponent` for taps.
- [ ] Every string in `Localizable.xcstrings` with Indonesian, and in
      `LocalizationTests`.
- [ ] New destination wired through `AppScreen` → `SceneManager` →
      `ContentView`, with a `SceneManagerTests` case.
- [ ] `#Preview` builds; ⌘U passes.
