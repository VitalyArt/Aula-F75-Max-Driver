# Premium UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a code-drawn F75 Max keyboard stage with live RGB preview, an exact 128 × 128 screen preview, saved lighting profiles, and release-level polish to the sidebar app.

**Architecture:** Pure, unit-tested logic first: keyboard layout data, an effect renderer, a screen-stream decoder, and a profile store. Then SwiftUI views draw the stage with `Canvas` + `TimelineView` and rebuild the Lighting, Screen and Home pages on top of that logic. `AppViewModel` only gains last-applied lighting tracking; device code does not change.

**Tech Stack:** Swift 6, SwiftUI (macOS 14+), SwiftPM, XCTest (new test target), `UserDefaults`, ImageIO.

**Spec:** `docs/superpowers/specs/2026-10-16-premium-ui-design.md`. Builds on the uncommitted branch `feat/sidebar-ui` (spec `2026-10-16-ui-redesign-design.md`).

## Global Constraints

- macOS app only (`Sources/AulaF75MaxDriver/`). Do not touch Linux, Android, or `Sources/AulaCore/`.
- Do not modify `AulaDevice.swift`, `WirelessAulaDevice.swift`, `HIDDeviceMonitor.swift`, or `HIDInputMonitor.swift`. Do not change `DisplayEncoder.swift`'s behaviour.
- No third-party dependencies.
- Do not ship the owner's reference photo. The keyboard is drawn in code.
- The Apple-structured pages (Performance, Settings, Diagnostics, Activity Log) get no neon glow and no uppercase headings.
- Every user-facing string goes through `L10n.text` / `L10n.format` and exists in all 7 lproj files. `python3 scripts/check_localization.py` must print `OK`.
- The RGB preview shows the caption "Preview is an approximation of the keyboard's effect". The screen preview is decoded from the same bytes that get uploaded.
- Animation pauses when its view is off-screen, and shows a static frame when `accessibilityReduceMotion` is on.
- **Git (owner's rule):** no `git commit` or `git push` by anyone without the owner's explicit OK. No AI co-author lines. Codex never commits.
- **Budget (owner's rule):** stay under 75% of the weekly Claude limit. Codex implements; Claude writes briefs and reviews diffs.

## Review Focus

1. **The window is hidden or minimised, or the page is not visible.** The stage stops animating and CPU drops to idle. Manual check in Task 4: Activity Monitor shows the app at about 0% CPU with the window minimised.
2. **A 200+ frame GIF.** Encoding and decoding run off the main thread, the UI stays responsive, and frames are capped at 255. Test in Task 2 (`testFrameCountMatchesStreamHeader`), plus a manual drop in Task 6.
3. **Corrupted saved-profile data in `UserDefaults`.** The store starts empty without crashing and does not re-seed the starter profiles over the user's intent. Test in Task 3 (`testCorruptDataLoadsEmptyWithoutReseeding`).
4. **Deleting the selected profile.** The selection becomes `nil` and nothing else changes. Test in Task 3 (`testDeletingSelectedProfileClearsSelection`).
5. **Selecting a profile while a command runs, or with no receiver.** It loads into the preview and sends nothing. Manual check in Task 5.

---

## File Map

| File | Responsibility |
|------|----------------|
| `Package.swift` (modify) | Add test target `AulaF75MaxDriverTests`. |
| `Sources/AulaF75MaxDriver/Lighting/LightingSettings.swift` (new) | `LightingSettings` value type shared by renderer, profiles, model. |
| `Sources/AulaF75MaxDriver/Lighting/LightingEffectRenderer.swift` (new) | Pure function: settings + key position + time → colour. |
| `Sources/AulaF75MaxDriver/Lighting/LightingProfileStore.swift` (new) | `LightingProfile`, `LightingProfileStore` (persistence). |
| `Sources/AulaF75MaxDriver/Keyboard/KeyboardLayout.swift` (new) | F75 Max layout data from the reference photo. |
| `Sources/AulaF75MaxDriver/Keyboard/KeyboardStageView.swift` (new) | Draws case, under-glow, caps, screen, knob. |
| `Sources/AulaF75MaxDriver/Screen/ScreenPreviewDecoder.swift` (new) | `EncodedDisplayStream` → frames. |
| `Sources/AulaF75MaxDriver/Screen/ScreenPreviewView.swift` (new) | Large pixel-crisp animated preview + frame strip. |
| `Sources/AulaF75MaxDriver/Views/LightingView.swift`, `ScreenView.swift`, `HomeView.swift` (rewrite) | Pages on the dark stage. |
| `Sources/AulaF75MaxDriver/Views/ProfilesPanel.swift` (new) | Save, rename, update, delete, select UI. |
| `Sources/AulaF75MaxDriver/ContentView.swift`, `AulaF75MaxDriverApp.swift` (modify) | Inject store, shortcuts, header, transitions. |
| `Sources/AulaF75MaxDriver/AppViewModel.swift` (modify) | Last-applied lighting, load settings, screen preview state. |
| `Tests/AulaF75MaxDriverTests/*.swift` (new) | Unit tests. |

---

### Task 1: Test target, `LightingSettings`, keyboard layout, effect renderer

**Files:**
- Modify: `Package.swift` (inside the `#if os(macOS)` block, append `.testTarget(name: "AulaF75MaxDriverTests", dependencies: ["AulaF75MaxDriver"])`)
- Create: `Lighting/LightingSettings.swift`, `Lighting/LightingEffectRenderer.swift`, `Keyboard/KeyboardLayout.swift`
- Test: `Tests/AulaF75MaxDriverTests/LightingEffectRendererTests.swift`, `KeyboardLayoutTests.swift`

**Interfaces (Produces):**
- `struct LightingSettings: Codable, Equatable, Sendable { var mode: Int; var brightness: Int; var speed: Int; var direction: Int; var colorful: Bool; var red: Int; var green: Int; var blue: Int }`, with `var rgbInteger: Int` equal to `(red << 16) | (green << 8) | blue`.
- `struct RGB: Equatable, Sendable { var r: Double; var g: Double; var b: Double }` (0...1 each), with `var luminance: Double` = 0.2126r + 0.7152g + 0.0722b.
- `enum LightingEffectRenderer { static func color(for settings: LightingSettings, at position: CGPoint, time: TimeInterval) -> RGB }`
  - `position` is normalised to 0...1 across the keyboard.
  - Output is scaled by `Double(brightness) / 5`.
  - `speed` 1...5 scales animation rate.
  - `direction`: 0 = right, 1 = down, 2 = left, 3 = up; it sets the axis and sign of travelling effects.
  - `colorful == true` uses a hue sweep; otherwise the fixed colour.
  - Every mode id 0...19 has a branch. Unknown ids fall back to a slow rainbow.
- `struct KeyboardKey: Identifiable { let id: String; let label: String; let frame: CGRect; let row: Int; let tone: KeycapTone }` (frame in key units). `enum KeycapTone { case light, dark }`.
- `struct KeyboardLayoutSpec { let keys: [KeyboardKey]; let size: CGSize; let screenFrame: CGRect; let knobCenter: CGPoint; let knobRadius: CGFloat }` and `enum KeyboardLayout { static let f75Max: KeyboardLayoutSpec }`.
  - Rows exactly as the spec's "Keyboard model: reference look".
  - `tone`: rows 0–2 and Backspace/Enter are `.light`; rows 3–5 are `.dark`. Row 3 alternates for the "mixed" look.

- [ ] **Step 1: Write the failing tests**
```swift
func testLedOffIsBlack()          // mode 0 → RGB(0,0,0) at any position/time
func testStaticUsesChosenColour() // mode 1, colorful false, (255,0,0), brightness 5 → r≈1, g≈0, b≈0 (accuracy 0.01)
func testBrightnessScales()       // mode 1 white: luminance(brightness 1) < luminance(brightness 5) and ratio ≈ 0.2
func testDeterministic()          // same inputs twice → equal
func testDirectionChangesPhase()  // mode 11 colorful, t=1.0, pos (0.3,0.5): direction 0 != direction 2
func testAllModesProduceValidColours() // modes 0...19, components all within 0...1
func testF75KeyCount()            // KeyboardLayout.f75Max.keys.count == 80  (rows: 13 + 15 + 15 + 14 + 14 + 9)
func testNoKeysOverlap()          // no two key frames intersect
func testScreenAndKnobRightOfF12()// screenFrame.minX > frame of "F12".maxX; knobCenter.x > screenFrame.maxX
```
- [ ] **Step 2: Run them and see them fail.** Run `swift test --filter LightingEffectRendererTests` and `swift test --filter KeyboardLayoutTests`. Expected: they do not compile (the types are missing).
- [ ] **Step 3: Implement the three files.** Effect approximations: Breath (sine pulse), Spectrum (whole board hue cycle), Rolling/Scrolling/Flowing (hue wave along the direction axis), Ripples/Outward/Explode (rings from the centre), Glittering/Falling (deterministic hash-based sparkle using key position and `floor(time*rate)`), SingleOn/SingleOff (static fixed colour). Anything not listed gets a sensible choice of the builder's.
- [ ] **Step 4: Run them and see them pass.** Run `swift test`. Expected: all tests pass, and `make macos-build` succeeds.

### Task 2: Screen preview decoder

**Files:** Create `Screen/ScreenPreviewDecoder.swift`. Test `Tests/AulaF75MaxDriverTests/ScreenPreviewDecoderTests.swift`.

**Interfaces (Produces):**
- `struct ScreenPreviewFrame { let image: CGImage; let duration: TimeInterval }`
- `enum ScreenPreviewDecoder { static func frames(from stream: EncodedDisplayStream) -> [ScreenPreviewFrame] }`
  - The header byte `[0]` is the frame count. Bytes `[1...count]` are delays, where `duration = Double(byte) / 500`.
  - Frame `i` starts at `AulaConstants.headerLength + i * AulaConstants.frameBytes`.
  - Each pixel is a little-endian RGB565 value (low byte first). Expand to 8 bits with `(v << 3) | (v >> 2)` for 5-bit channels and `(v << 2) | (v >> 4)` for 6-bit.
  - Row 0 is the top row. The image is 128 × 128, sRGB.

- [ ] **Step 1: Write the failing tests.** Each test builds a GIF in a temp directory with `CGImageDestination`.
```swift
func testRoundTripTwoFrameGif()  // frame0 solid red, frame1 solid blue, delays 0.1 and 0.2, fit .stretch
  // → frames.count == 2; durations == [0.1, 0.2] (accuracy 0.002)
  // frame0 centre pixel r >= 248, g <= 4, b <= 4; frame1 centre pixel b >= 248
func testFrameCountMatchesStreamHeader() // frames.count == stream.frameCount == Int(stream.data[0])
func testStaticPngGivesOneFrame()        // a single PNG → 1 frame
```
- [ ] **Step 2: Run it and see it fail.** Run `swift test --filter ScreenPreviewDecoderTests`. Expected: it does not compile.
- [ ] **Step 3: Implement the decoder.** Build each frame with `CGContext` over a decoded RGBA buffer, then `makeImage()`.
- [ ] **Step 4: Run it and see it pass.** Run `swift test`. Expected: all tests pass.

### Task 3: Profiles store and model hooks

**Files:**
- Create `Lighting/LightingProfileStore.swift`.
- Modify `AppViewModel.swift`: the RGB properties and `applyRGB()`.
- Test `Tests/AulaF75MaxDriverTests/LightingProfileStoreTests.swift`.

**Interfaces (Produces):**
- `struct LightingProfile: Codable, Identifiable, Equatable { let id: UUID; var name: String; var settings: LightingSettings }`
- `@MainActor final class LightingProfileStore: ObservableObject` with:
  - `@Published private(set) var profiles: [LightingProfile]`
  - `@Published var selectedID: UUID?`
  - `init(defaults: UserDefaults = .standard, storageKey: String = "lighting.profiles.v1")`
  - `func add(name: String, settings: LightingSettings) -> LightingProfile`
  - `func update(_ id: UUID, settings: LightingSettings)`
  - `func rename(_ id: UUID, to name: String)`
  - `func delete(_ id: UUID)`
  - `var selectedProfile: LightingProfile? { get }`
  - Persist after every change.
  - Seed the starters only when `storageKey` is absent:
    - "Rainbow Wave": mode 11, brightness 4, speed 3, direction 0, colorful true, colour (0,122,255).
    - "Calm Breath": mode 7, brightness 3, speed 2, direction 0, colorful false, colour (0,122,255).
    - "Off": mode 0, brightness 1, speed 1, direction 0, colorful true, colour (0,122,255).
    - Names go through `L10n.text` at seeding time.
- In `AppViewModel`:
  - `var lightingSettings: LightingSettings { get }`, built from `rgbMode`, `rgbBrightness`, `rgbSpeed`, `rgbDirection`, `rgbColorful`, `rgbColor`.
  - `func loadLighting(_ settings: LightingSettings)`, which sets those properties.
  - `@Published private(set) var lastAppliedLighting: LightingSettings?`, set inside the success path of `applyRGB()` on the main actor.
  - `var hasUnappliedLighting: Bool { lastAppliedLighting != lightingSettings }`

- [ ] **Step 1: Write the failing tests.** Each test uses a fresh `UserDefaults(suiteName: UUID().uuidString)!`.
```swift
func testFirstLaunchSeedsThreeStarters()       // profiles.map(\.name).count == 3
func testSecondLaunchDoesNotReseed()           // delete all, new store on same defaults → 0 profiles
func testAddRenameUpdateDeletePersist()        // each op, then a new store on same defaults sees the change
func testDeletingSelectedProfileClearsSelection()
func testCorruptDataLoadsEmptyWithoutReseeding() // defaults.set(Data("x".utf8), forKey: key) → profiles.isEmpty
```
- [ ] **Step 2: Run it and see it fail.** Run `swift test --filter LightingProfileStoreTests`. Expected: it does not compile.
- [ ] **Step 3: Implement the store and the `AppViewModel` hooks.** For colour, build `Color(.sRGB, red: Double(r)/255, …)` and read back through the existing `rgbInteger`.
- [ ] **Step 4: Run it and see it pass.** Run `swift test && make macos-build`. Expected: all tests pass and the build succeeds.

### Task 4: Keyboard stage view

**Files:** Create `Keyboard/KeyboardStageView.swift`. Modify `Views/HomeView.swift` (the hero).

**Interfaces:**
- Consumes `KeyboardLayout.f75Max` and `LightingEffectRenderer` (Task 1).
- Produces `struct KeyboardStageView: View` with `init(settings: LightingSettings, screenImage: CGImage? = nil, isAnimating: Bool = true)`.
  - Draw order in one `Canvas`, inside `TimelineView(.animation(paused: !isAnimating || reduceMotion))`:
    1. Case, a rounded rect with a rim.
    2. Plate.
    3. Under-glow: per key, the renderer colour filled under the key and blurred with `context.addFilter(.blur(radius:))` in a separate layer.
    4. Caps, with a tone gradient by `KeycapTone` and a faint edge tint.
    5. The screen: `screenImage`, or a dark placeholder with a clock.
    6. The knob, a radial gradient.
    7. The light bar under Space and the status dot.
  - Scales to fit its frame while keeping the layout aspect ratio.
- `@Environment(\.accessibilityReduceMotion)`, plus `.onAppear` / `.onDisappear`, toggle a local `@State var isVisible`.

- [ ] **Step 1: Build the stage.** Replace the `keyboard` SF Symbol in the Home summary card with a `KeyboardStageView`.
  - Settings: `model.lastAppliedLighting`, or when nil a neutral idle look (mode 7 Breath, brightness 2, speed 2, colorful false, white 255,255,255), with a fixed height of about 220 on a dark rounded backdrop.
  - Keep the battery and connection rows beside or below it.
- [ ] **Step 2: Verify.** Run `make macos-build && make macos-app`, then open the app. Expected:
  - Home shows the keyboard with an animated rainbow under-glow, and the screen and knob at the top right.
  - Review Focus 1: minimise the window, and Activity Monitor shows about 0% CPU after 5 seconds.

### Task 5: Lighting page and profiles panel

**Files:** Rewrite `Views/LightingView.swift`. Create `Views/ProfilesPanel.swift`. Modify `AulaF75MaxDriverApp.swift` (create a `@StateObject` `LightingProfileStore` and inject it with `.environmentObject`).

**Interfaces:** Consumes `KeyboardStageView`, `LightingProfileStore`, and `AppViewModel.lightingSettings` / `loadLighting` / `lastAppliedLighting` / `hasUnappliedLighting`.

- [ ] **Step 1: Build the page layout.**
  - A dark stage at the top with `KeyboardStageView(settings: model.lightingSettings)`.
  - The "Preview · not applied" badge, shown while `hasUnappliedLighting`.
  - The approximation caption.
  - A horizontal `ScrollView` of 20 effect tiles from `WirelessAulaLabels.rgbModes`. Each tile is a mini renderer swatch plus its name, and the selected tile is outlined in the accent colour.
  - Cards: Brightness, Speed, Direction and Colour (Rainbow / Single + `ColorPicker`).
  - **Revert** calls `loadLighting(lastAppliedLighting!)` and is disabled when nil or not dirty.
  - **Apply to Keyboard** calls `model.applyRGB()` with ⌘↩. Its disabled rule is unchanged.
  - `DeviceRequirementNote(.receiver)`.
- [ ] **Step 2: Build `ProfilesPanel`.**
  - A list or chips of `store.profiles`, with the selected one highlighted.
  - **Save as New Profile…** (⌘S): a sheet with a name field.
  - **Update** writes the current settings into the selected profile.
  - **Rename…**.
  - **Delete…** with a confirmation dialog.
  - The empty state reads "No saved profiles yet. Set up a look you like and save it."
  - Selecting a profile:
    - If `model.lightingSettings` differs from both `lastAppliedLighting` and the selected profile's settings, first confirm "Discard your unsaved lighting changes?".
    - Then `loadLighting(profile.settings)`, set `store.selectedID`, and call `model.applyRGB()` only if `model.isDonglePresent && !model.isWorking`.
- [ ] **Step 3: Verify.** Run `swift test && python3 scripts/check_localization.py && make macos-build`. Then run the app with the receiver connected:
  - Click an effect tile: the stage changes and the badge appears.
  - Apply: the keyboard changes and the badge clears.
  - ⌘S, save "Test": it appears in the list.
  - Select "Off": the keyboard goes dark.
  - Review Focus 5: unplug the receiver and select a profile. The preview changes and nothing is sent; the log has no "Applying RGB".

### Task 6: Screen page with exact preview

**Files:**
- Create `Screen/ScreenPreviewView.swift`.
- Rewrite `Views/ScreenView.swift`.
- Modify `AppViewModel.swift`:
  - Add `@Published private(set) var screenPreviewFrames: [ScreenPreviewFrame]`.
  - Add `func refreshScreenPreview()`, which encodes `selectedFile` with `fitMode` on a detached task, decodes it with `ScreenPreviewDecoder`, and publishes the result on the main actor.
  - Call it when `selectedFile` or `fitMode` changes.
  - Add `func selectImage(at url: URL)` for drag and drop, applying the same allowed types as `chooseFile()`.

**Interfaces:** Consumes `ScreenPreviewDecoder` (Task 2) and `KeyboardStageView(screenImage:)` (Task 4).
- `struct ScreenPreviewView: View` with `init(frames: [ScreenPreviewFrame])`:
  - Plays the frames by their durations using a `TimelineView` schedule.
  - Draws with `.interpolation(.none)` at 256–320 pt, with a 1 px grid overlay every 2 px of scale.
  - Shows a frame strip and a "%d frames" label.

- [ ] **Step 1: Build the page.**
  - A dark stage with `ScreenPreviewView` on the left and the keyboard (its screen showing the current frame) on the right, or stacked when narrow.
  - The page accepts dropped files with `.dropDestination(for: URL.self)`.
  - Cards: Fit (live re-preview), Slot, Clock (Sync), and Upload with progress, keeping the existing disabled rules.
  - The empty state reads "Drop a GIF or image here".
- [ ] **Step 2: Verify.** Run `swift test && python3 scripts/check_localization.py && make macos-build`. Then run the app:
  - Drop a GIF: it plays. Switching Fit/Fill/Stretch updates within about 1 second.
  - Upload: the keyboard screen matches the preview.
  - Review Focus 2: drop a GIF with 200+ frames, and the window keeps responding while the preview loads.

### Task 7: Polish pass and translations

**Files:** Modify `ContentView.swift` and `Views/Components.swift`, plus all 7 `Localizable.strings`.

- [ ] **Step 1: Sidebar header.** The app icon (`AppIcon.png` from the bundle) and "Aula F75 Max" go above the list.
- [ ] **Step 2: Page shortcuts.** ⌘1–⌘7 select pages, through a `Commands` menu "View" or `.keyboardShortcut` on hidden buttons.
- [ ] **Step 3: Page transition.** A 0.15 s fade on the detail when `selection` changes, disabled under Reduce Motion.
- [ ] **Step 4: Home additions.** A profile switcher row (chips that call the same select logic as Task 5) is added to Home.
- [ ] **Step 5: Style the requirement note for the stage.** `DeviceRequirementNote` reads well on the dark stage, using a material background.
- [ ] **Step 6: Translations.** Add every new key to all 7 languages (drafts), then generate `docs/superpowers/plans/2026-10-16-premium-ui-translations.md` with the same table format as before.
- [ ] **Step 7: Verify.** Run `swift test && python3 scripts/check_localization.py && make macos-build && make macos-app`. Expected: all pass. `strings -a "build/Aula F75 Max Driver.app/Contents/MacOS/Aula F75 Max Driver" | grep -c KeyboardStageView` is at least 1.

### Task 8: Final review (orchestrator)

- [ ] Run a Codex read-only review (lane `review`) over `git diff main`, the untracked files, this plan and the spec, with the Review Focus list copied in.
- [ ] Fix Critical/Important findings with one delta brief to the same Codex session. Rerun `swift test` and the build.
- [ ] Hand over to the owner, uncommitted, with the rulings list.

## Execution (budget-aware)

Codex runs on the `implement` lane, with three dispatches instead of eight, each with one brief:
- **Dispatch A:** Tasks 1–3, pure logic and tests. Low risk; gate is `swift test`.
- **Dispatch B:** Tasks 4–5, stage, Lighting and profiles.
- **Dispatch C:** Tasks 6–7, Screen and polish.

After each dispatch, Claude reads the diff, reruns the gates, and checks it in the running app where a task says to.
