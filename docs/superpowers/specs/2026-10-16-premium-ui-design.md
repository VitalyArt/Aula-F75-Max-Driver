# Premium UI: Keyboard Stage, Live Previews, Lighting Profiles

Date: 2026-10-16
Status: draft, awaiting approval
Builds on: `docs/superpowers/specs/2026-10-16-ui-redesign-design.md` (the sidebar redesign, implemented and uncommitted on branch `feat/sidebar-ui`).
Scope: macOS app only (`Sources/AulaF75MaxDriver/`).

## Intent

The sidebar redesign made the app organised. The owner now wants it to feel
"premium and polished, like a final app release… a good proper app, not just
made for simple functions." The reference bar, in the owner's words: Apple
style, plus "something like Logitech / Razer software, as Aula software is so
bad." Two things were named explicitly: show the RGB effect on a keyboard
model, and show how a GIF will look on the keyboard's screen. Saved lighting
profiles (save, name, switch presets) like G Hub were added on top.

Success: a new owner of an F75 Max opens the app, sees their keyboard rendered
on screen, picks an effect and watches it play on the model before sending it,
drops a GIF and sees exactly what the keyboard display will show, and switches
between saved lighting looks in one click.

## Goals

1. **Visual direction "C · Blend" (decided by owner from mockups).** Apple
   structure everywhere (sidebar, native controls, grouped forms, light and dark
   mode). Lighting and Screen pages, plus the Home hero, sit on a dark "stage":
   a straight-on render of the F75 Max matching the owner's reference photo (see "Keyboard model: reference look").
2. **Live RGB preview.** The keyboard model animates the selected effect using
   the current brightness, speed, direction and colour, before anything is sent.
3. **Exact screen preview.** The chosen image or GIF plays in a large 128 × 128
   preview that shows exactly what the keyboard will receive.
4. **Lighting profiles.** Save the current lighting settings under a name,
   switch between saved profiles, rename, delete.
5. **Release-level polish** across all pages (see "Polish" below).

## Non-goals

- No new keyboard protocol features. No per-key RGB (the firmware commands the
  app knows set one effect for the whole board). No on-keyboard profile slots.
- No changes to `AulaDevice.swift`, `WirelessAulaDevice.swift`,
  `DisplayEncoder.swift`'s encoding behaviour, `HIDDeviceMonitor.swift`,
  `HIDInputMonitor.swift`.
- No new third-party dependencies.
- Linux and Android apps untouched.

## Anti-goals (failure even if it builds)

- The RGB preview claims to be exact. It is an approximation and must say so
  in a short caption ("Preview is an approximation of the keyboard's effect").
- The screen preview differs from what the keyboard shows. It must be built
  from the same encoded bytes that get uploaded.
- The animated keyboard makes the app sluggish or burns CPU when the window is
  hidden or the page is not visible.
- Gamer-style chrome (neon glow, uppercase headings) leaks into the
  Apple-structured pages (Settings, Performance, Diagnostics, Activity Log).
- Selecting or saving a profile silently loses the user's unsaved edits.

## Keyboard model: reference look (decided by owner's photo)

The owner supplied a top-down product photo of the F75 Max and asked for "the
same look", drawn in code. The photo is a reference only; it is not shipped in
the app (it is Aula's marketing image). Draw it flat and straight-on like the
photo (this replaces the 3D tilt in the mockup).

- **Case:** black, rounded rectangle with a thin raised rim; a slightly lighter
  inner plate.
- **Row 0 (function row):** Esc, gap, F1–F4, gap, F5–F8, gap, F9–F12. To the
  right of F12: a small landscape colour **screen** (about 1.5 key units wide,
  1 unit tall) showing the clock or the uploaded image, then a round black
  metal **knob** at the far right. No other keys in row 0.
- **Rows 1–5 (75% block with a right-hand column):**
  - Row 1: `` ` `` 1–0 - =, Backspace (2u), one right-column key.
  - Row 2: Tab (1.5u), Q–P [ ] \ (1.5u), one right-column key.
  - Row 3: Caps (1.75u), A–' , Enter (2.25u), one right-column key.
  - Row 4: Left Shift (2.25u), Z–/, Right Shift (1.75u), ↑, one right-column key.
  - Row 5: Ctrl, Win, Alt (1.25u each), Space (6.25u), Alt, Fn (1u each), then
    ← ↓ → set slightly apart.
- **Keycaps:** two-tone gradient set, light grey on the top rows fading to
  black on the bottom rows (rows 0–2 light, row 3 mixed, rows 4–5 dark); the
  big modifiers in the upper rows (Backspace, Enter) stay light. Small
  front-printed legends; legends may be omitted at small sizes.
- **Lighting:** the RGB is an under-glow: colour bleeds onto the plate around
  and between the caps, not a colour fill on the caps. Draw a blurred coloured
  shape under each key, coloured by `LightingEffectRenderer`, then the cap on
  top with only a faint tint at its edges. The photo shows the rainbow wave:
  red on the left through yellow, green, cyan, to blue on the right.
- **Small details:** a thin light bar under the space bar and a small status
  dot at the left edge beside the Caps row; both may use the effect colour.

## Page-by-page (decided unless marked "my call")

### Lighting (dark stage)
- Top: the keyboard stage with the live preview.
- Badge on the stage: "Preview · not applied" whenever the preview settings
  differ from what was last applied in this session; hidden when they match.
- Effects: a horizontal strip of tiles, one per firmware effect (all 20 entries
  in `WirelessAulaLabels.rgbModes`, including LED Off), each with a small
  animated or static thumbnail and the localised name. Replaces the dropdown.
- Controls below the stage as cards: Brightness 1–5, Speed 1–5, Direction
  (4 options), Colour (Rainbow / Single + colour well). Every change updates the
  preview immediately.
- Buttons: **Revert** (restore the last-applied values) and **Apply to
  Keyboard** (calls the existing `model.applyRGB()`).
- **Profiles** panel (see below).

### Screen (dark stage)
- Large 128 × 128 preview, scaled up with nearest-neighbour sampling so pixels
  stay crisp, plus a subtle pixel-grid overlay.
- The preview is built by running the existing
  `DisplayEncoder.encodeImage(at:fitMode:)` and decoding its RGB565 frames and
  per-frame delays back into images. Changing Fit/Fill/Stretch re-encodes and
  updates the preview.
- Animated GIFs play at their encoded delays. A frame strip shows the frame
  count (capped as the encoder caps it, `AulaConstants.maxFrames`).
- Drag and drop an image file onto the preview to select it (same file types as
  the Choose File panel). Choose File stays.
- The small screen on the keyboard model shows the same preview.
- Clock sync, slot, upload button and progress stay, restyled as cards.

### Home
- Hero: the keyboard model (static or slow idle animation, my call: shows the
  last-applied lighting if known this session, otherwise a neutral idle glow),
  name, connection status chips, large battery reading.
- Quick actions stay (Sync Clock, Open Lighting, Open Screen), plus a
  **profile switcher** showing saved lighting profiles for one-click switching.

### Performance, Settings, Diagnostics, Activity Log
- Keep the current native grouped-form layout. Only shared polish applies.

## Lighting profiles (decided)

- A profile stores: name, effect id (`rgbMode`), brightness, speed, direction,
  rainbow flag (`rgbColorful`), colour (stored as sRGB red/green/blue 0–255).
- Stored locally on the Mac (my call: a JSON array in `UserDefaults` under one
  key). Not stored on the keyboard.
- Actions: **Save as New Profile…** (asks for a name), **Update** the selected
  profile with the current settings, **Rename**, **Delete** (with confirmation),
  and select.
- Selecting a profile (my call): loads its values into the controls and preview
  **and applies it to the keyboard immediately** when the receiver is
  connected, because one-click switching is the point of profiles. If the
  receiver is missing, it loads into the preview only and the Apply button stays
  available for later.
- Unsaved-edits rule (anti-goal above): if the current settings differ from
  both the last-applied values and the selected profile, selecting another
  profile first asks "Discard your unsaved lighting changes?".
- First launch: three built-in starter profiles (my call: "Rainbow Wave"
  = Rolling rainbow, "Calm Breath" = Breath single colour blue, "Off" = LED
  Off). They behave like any other profile and can be deleted.
- Empty state: "No saved profiles yet. Set up a look you like and save it."

## Polish (decided)

- One spacing scale (4/8/12/16/24) and type scale used consistently.
- Page transitions: a short fade when switching sidebar pages (respect the
  system "Reduce motion" setting by disabling it).
- The stage animation pauses when its page is not visible or the window is
  minimised or occluded, and honours "Reduce motion" by showing a static frame.
- App icon (existing `AppIcon.png`) and device name in the sidebar header.
- Every page has a designed disconnected state (the existing
  `DeviceRequirementNote`, restyled to sit well on the dark stage).
- Keyboard shortcuts: ⌘1–⌘7 switch pages; ⌘↩ applies on Lighting and
  Performance; ⌘S on Lighting opens **Save as New Profile…** (my call: it
  never overwrites an existing profile; updating stays an explicit button).

## Architecture (decided)

- `KeyboardLayout`: static data describing the F75 Max 75% layout (rows of keys
  with widths in key units, position of the screen and knob). Plain data, no UI.
- `LightingEffectRenderer`: a pure function from (effect id, brightness, speed,
  direction, colour settings, key centre position, time) to a colour. No
  SwiftUI state. Each of the 20 effects gets an approximation (unknown ones fall
  back to a slow rainbow).
- `KeyboardStageView`: draws the layout with SwiftUI `Canvas` inside a
  `TimelineView(.animation)`, colouring each key via the renderer. Used on
  Lighting, Screen (static lighting, live screen) and Home.
- `ScreenPreviewModel`: turns an `EncodedDisplayStream` into an array of
  (image, delay) frames. Lives next to the views, not inside `DisplayEncoder`
  (whose behaviour must not change); it may need read access to
  `AulaConstants` values.
- `LightingProfile` (Codable struct) and `LightingProfileStore`
  (`ObservableObject`, injected with `.environmentObject` from
  `AulaF75MaxDriverApp`): load, save, update, rename, delete, persist.
- `AppViewModel` changes (allowed, small): remember the last-applied lighting
  values after a successful `applyRGB()` so Revert and the "not applied" badge
  work; a method to load a profile's values into the RGB properties. No change
  to how commands are sent.

## Testing (my call)

Add a Swift test target `AulaF75MaxDriverTests` under `Tests/` (the repo's
AGENTS.md names this location) using `@testable import AulaF75MaxDriver`, run
with `swift test`. Cover:
- `LightingEffectRenderer`: deterministic output for fixed inputs; brightness 1
  is dimmer than 5; LED Off is black; Static uses the chosen colour; direction
  changes the phase.
- `ScreenPreviewModel`: round-trip a small generated image through
  `DisplayEncoder` and back; frame count and delays match; pixel colours match
  within RGB565 precision.
- `LightingProfileStore`: save, rename, delete, persistence round-trip using an
  isolated `UserDefaults` suite; starter profiles appear only on first launch.
Manual checks on hardware stay as in the previous spec.

## Localisation

Same rule as before: every new string via `L10n`, in all 7 languages, drafted
translations reviewed by the owner; `scripts/checks/check_localization.py` must pass.
Effect names already have keys.

## Budget constraint (owner)

The owner caps Claude usage at 75% of the weekly limit (66% used when this was
written). The plan should hand implementation to Codex (implement lane) in
well-bounded tasks, with Claude writing briefs and reviewing diffs.

## Left to the builder

- Exact look of each effect approximation, thumbnail art, colours of the stage
  backdrop, key cap shading.
- Exact profile UI control (list, menu, or segmented chips) as long as save,
  rename, delete and one-click select are all reachable on Lighting and select
  is reachable on Home.
- Exact animation curves and durations.
