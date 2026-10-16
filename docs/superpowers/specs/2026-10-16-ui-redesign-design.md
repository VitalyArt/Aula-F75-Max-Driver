# macOS UI Redesign: Sidebar Navigation

Date: 2026-10-16
Status: draft, awaiting approval
Scope: macOS app only (`Sources/AulaF75MaxDriver/`). Linux and Android apps are untouched.

## Intent

Today `ContentView.swift` (938 lines) puts every feature in one long scroll:
status cards, a two-column grid of panels (USB screen, 2.4G control, HID
endpoints, app settings), and a log at the bottom. Research tools (keymap dump,
byte-write experiment, raw input monitor) sit right next to everyday controls.

The owner's words: "Everything feels cluttered in one long scroll. I can never
find the setting I want quickly. Kinda complicated for users who don't know and
just want a simple app to use."

Success: a user who has never seen the app can find lighting, battery, clock
sync, or sleep settings in one click, and never has to see protocol-research
tools unless they go looking.

## Goals

- Replace the single scroll with a macOS sidebar (`NavigationSplitView`), the
  same pattern as System Settings. Chosen by the owner from two mockups
  (sidebar vs. top tabs).
- One page per task, each page short enough to fit without scrolling at the
  default window size.
- Separate everyday features from research and diagnostic tools.
- Native macOS look: system colours, standard grouped forms (`Form` with
  `.formStyle(.grouped)`), SF Symbols. Works in both light and dark mode.
- Plain-language status ("USB cable not connected") instead of transport jargon
  ("0 endpoint(s)").
- When a control is disabled because a cable or dongle is missing, the page says
  why, next to the control.

## Non-goals

- No changes to device protocol code (`AulaDevice`, `WirelessAulaDevice`,
  `DisplayEncoder`, `HIDDeviceMonitor`, `HIDInputMonitor`).
- No new features. Every existing action stays reachable.
- No changes to Linux or Android UIs.
- No menu-bar extra, no onboarding wizard.

## Anti-goals (would count as failure even if it builds)

- Any existing feature becomes unreachable.
- Research tools (byte-write experiment, keymap dump) appear on a main page.
- Hardcoded white text or dark backgrounds that break light mode.
- A destructive action (factory reset, test byte write) can run without a
  confirmation step.

## Structure (decided)

Sidebar, top to bottom:

| Page | Contents (moved from) |
|------|----------------------|
| **Home** | Keyboard name, connection status for USB cable and 2.4G receiver in plain words, battery % with refresh button, quick actions: Sync Clock, a "Lighting" tile and a "Screen image" tile that navigate to those pages. Tiles show no current values (see "Home tiles" below). (from `connectionOverview`, battery row of `wirelessPanel`) |
| **Lighting** | Effect picker, brightness 1–5, speed 1–5, direction, Rainbow vs single colour + colour picker, **Apply Lighting** button. (from RGB part of `wirelessPanel`) |
| **Screen** | Clock: Sync Clock button. Image: Choose File, file name, slot, fit mode, progress, Upload button. (from `wiredPanel` top half) |
| **Performance** | Key response, sleep time, Apply button, Enable/Disable Game Mode button (action button, as today, not a `Toggle`), Restore Command Key button. (from performance part of `wirelessPanel`) |
| **Settings** | Language picker, Launch at Login toggle, and at the bottom a "Danger zone" section with Factory Reset. (from `systemPanel`, factory reset part of `wiredPanel`) |
| *Advanced* group header | |
| **Diagnostics** | Scrolls (exempt from the no-scroll goal). Detected HID endpoints (wired + receiver), Rescan, Start/Stop Input Monitor, Keymap inspector (Dump), Keymap byte experiment (steppers + Write Test Byte). (from `endpointsPanel`, keymap parts of `wiredPanel`) |
| **Activity Log** | The operation log, full height, selectable text. (from `logPanel`) |

The sidebar footer shows a small status line: "Ready" or a spinner with
"Working…" while `model.isWorking` is true. This replaces the header `StatusPill`.

Default selected page on launch: Home.

### Action feedback (my call, from builder check)

All results and errors from `runTask` only reach `model.logLines`. With the log
on its own page, users would not see whether Apply or Sync worked. So:
- A one-line status bar at the bottom of the detail area shows
  `model.logLines.last` (or a spinner + "Working…" while `isWorking`). Clicking
  it opens Activity Log. Built from existing state; no model change.
- Diagnostics also embeds a compact log view (same content as Activity Log),
  because Keymap Dump, Input Monitor and Write Test Byte report only to the log.

### Home tiles (my call, from builder check)

The app cannot read lighting or Game Mode state back from the keyboard:
`rgb*` values reset to defaults on launch and `gameModeEnabled` starts `false`.
Showing them on Home could be wrong. Also, `setGameMode` and
`restoreCommandKey` send the current, possibly unapplied, `keyResponseLevel` and
`sleepTime`, so a Game Mode control away from those settings would send changes
the user never applied. Therefore Home shows no lighting values and no Game Mode
control; Game Mode stays on Performance next to the settings it sends. This
differs from the first mockup, which had a Game Mode toggle tile on Home.

### Mockups

Visual companion screens in `.superpowers/brainstorm/` (not committed). Key
points from the approved mockup:
- Home: a summary card (keyboard, connection chips, big battery number) above a
  row of three quick-action tiles.
- Lighting: one grouped form, one row per setting, Apply button bottom-right.

## Behaviour rules (decided)

- Lighting and Performance keep the explicit **Apply** button. Changing a
  control does not send anything to the keyboard until Apply. (This matches
  today's behaviour; the RGB command sends the whole profile at once.)
- Factory Reset keeps its existing `NSAlert` confirmation in
  `AppViewModel.factoryReset()`.
- Write Test Byte gets a confirmation dialog (SwiftUI `.confirmationDialog`)
  before it calls `model.testKeymapByteWrite()`. Today it runs immediately.
- Disabled-state rule: a page whose controls need the USB cable shows an inline
  note at the top of the relevant section when `!model.isWiredDevicePresent`;
  same for the receiver with `!model.isDonglePresent`. Controls stay disabled
  exactly as they are today (`isWorking` or missing device).
- While `model.isWorking`, controls that are disabled today stay disabled.

## Code organisation (decided)

- `ContentView.swift` becomes a thin shell: the `NavigationSplitView`, the
  sidebar list, and a `switch` on the selected page.
- One file per page in a new folder `Sources/AulaF75MaxDriver/Views/`:
  `HomeView.swift`, `LightingView.swift`, `ScreenView.swift`,
  `PerformanceView.swift`, `SettingsView.swift`, `DiagnosticsView.swift`,
  `ActivityLogView.swift`.
- A small `enum SidebarPage: String, CaseIterable, Identifiable` (title, SF
  Symbol, section) drives the sidebar.
- Small shared pieces (e.g. a "needs USB cable" inline note, the endpoint row)
  go in `Views/Components.swift`.
- Every page reads `@EnvironmentObject var model: AppViewModel`, same as today.
  No new view models.
- Remove the custom styling types that only exist for the old look:
  `AppBackground`, `Panel`, `StatusCard`, `StatusPill`, `ActionHeader`,
  `SectionDivider`, and the custom `LanguageSelector` (replaced by a standard
  `Picker` showing flag + name).

## Window (decided)

- Window becomes resizable with a minimum size around 760 × 520 and a default
  around 900 × 600. The fixed 1216 pt width goes away.
- Remove `WindowAppearanceConfigurator` (transparent title bar, hardcoded dark
  window background) from `AulaF75MaxDriverApp.swift`. `NavigationSplitView`
  provides standard window chrome.
  Note from project history: window buttons once disappeared on the macOS 27
  SDK because of `.ignoresSafeArea()` on the background; do not reintroduce it.

## Small model change (my call)

`AppViewModel.batteryStatusColor` returns `.white.opacity(0.42)` when unknown,
which is invisible in light mode. Change that branch to `.secondary`. This is
the only edit to `AppViewModel`.

## Localisation (decided)

All user-facing strings go through `L10n.text` / `L10n.format`, as today. Reuse
existing keys wherever the wording still fits. New keys (page titles like
"Home", "Lighting", plain-language status strings) are added to every
`Resources/*.lproj/Localizable.strings` file (en, es, kk, pt, ru, uz, zh-Hans).

- The builder drafts translations for all 6 non-English languages.
- The owner reviews them before the work counts as done. The plan includes a
  separate review step listing every new key with its 7 translations side by
  side.
- Keys that are no longer used can stay; removing them is optional cleanup.

## Verification

- `make macos-build` succeeds.
- `make macos-app`, then confirm the bundle has the fresh binary
  (`strings` on the executable finds a new string such as "Activity Log") before
  hardware testing. (Project history: packaging once shipped a stale binary.)
- Manual check, with keyboard on USB and receiver plugged in:
  each sidebar page opens; every action from the old UI is reachable; battery
  query, RGB apply, sync clock, image upload work; light and dark mode both
  readable; window resizes down to the minimum without clipping.
- Manual check with nothing plugged in: every disabled control has a visible
  reason on its page.

## Left to the builder

- Exact SF Symbols, spacing, and wording of helper text.
- Whether Home tiles are buttons or `GroupBox`es.
- Order of implementation and how to split commits.
