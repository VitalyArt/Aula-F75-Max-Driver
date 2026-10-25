# macOS Sidebar UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single long scroll in `ContentView.swift` with a native macOS sidebar app: Home, Lighting, Screen, Performance, Settings, and an Advanced group (Diagnostics, Activity Log).

**Architecture:** `ContentView` becomes a `NavigationSplitView` shell that owns the selected `SidebarPage` and switches between one view file per page in `Sources/AulaF75MaxDriver/Views/`. Every page reads the existing `AppViewModel` from the environment; the model, device and protocol code stay as they are (one colour fix). A bottom status bar shows the latest log line so users see results without opening the log.

**Tech Stack:** Swift 6, SwiftUI (macOS 14+), SwiftPM, `L10n` string lookup over `Resources/*.lproj/Localizable.strings`.

**Spec:** `docs/superpowers/specs/2026-10-16-ui-redesign-design.md`

## Global Constraints

- macOS app only: `Sources/AulaF75MaxDriver/`. Do not touch Linux, Android or `Sources/AulaCore/`.
- Do not modify `AulaDevice.swift`, `WirelessAulaDevice.swift`, `DisplayEncoder.swift`, `HIDDeviceMonitor.swift`, `HIDInputMonitor.swift`.
- The only `AppViewModel.swift` edit: `batteryStatusColor` unknown-and-no-dongle branch returns `.secondary` instead of `.white.opacity(0.42)`.
- No hardcoded `.white` / dark colours. Use system styles (`.primary`, `.secondary`, `.tint`, `Form` + `.formStyle(.grouped)`).
- No `.ignoresSafeArea()` on backgrounds (it hid the window buttons on the macOS 27 SDK before).
- Every user-facing string goes through `L10n.text` / `L10n.format`. Every key used in `ContentView.swift` or `Views/` exists in all 7 lproj files: en, es, kk, pt, ru, uz, zh-Hans. Non-English values are drafts for owner review.
- Every action that exists today stays reachable, with today's disabled conditions (`model.isWorking` or missing device).
- Lighting and Performance send nothing until their Apply button. Game Mode is an action button on Performance only, never a `Toggle`, never on Home.
- Window: minimum about 760 × 520, default about 900 × 600, resizable. No fixed 1216 pt width.
- **Git (owner's rule):** never `git commit` or `git push` without the owner's explicit OK in the current message. No `Co-authored-by` or AI attribution lines. Each task ends at "Pause for review", not a commit.

## Review Focus

1. **Device unplugged or plugged while a page is open.** The page's requirement note appears or disappears and its controls enable or disable at once, with no navigation needed. Checked in Task 8's manual run.
2. **Language changed in Settings.** The sidebar titles, the page titles and every picker's option labels switch to the new language without a relaunch, and the selected page stays selected. Test step in Task 6.
3. **Empty or very long log.** With no log lines the status bar shows "No activity yet". A long line is truncated to one line, not wrapped. Test step in Task 1.
4. **Minimum window size with long translations.** At 760 × 520 in Russian and Kazakh, no label is clipped and no control overlaps. Checked in Task 8.
5. **A command still running when the user switches pages.** The status bar and sidebar footer keep showing "Working…", and controls on the other pages stay disabled. Test step in Task 4.

---

## File Map

| File | Responsibility |
|------|----------------|
| `scripts/checks/check_localization.py` (new) | Fails if any `L10n` key used by the new UI is missing from any lproj file. |
| `Sources/AulaF75MaxDriver/ContentView.swift` (rewrite) | `NavigationSplitView` shell, sidebar list, page switch, status bar placement. |
| `Sources/AulaF75MaxDriver/Views/SidebarPage.swift` (new) | `SidebarPage` enum: title, SF Symbol, Main or Advanced group. |
| `Sources/AulaF75MaxDriver/Views/Components.swift` (new) | Shared pieces: `DeviceRequirementNote`, `StatusBar`, `LogTextView`, `EndpointGroup`, `EndpointRow`. |
| `Sources/AulaF75MaxDriver/Views/HomeView.swift` … `ActivityLogView.swift` (new, 7 files) | One page each. |
| `Sources/AulaF75MaxDriver/AulaF75MaxDriverApp.swift` | Window sizing; remove `WindowAppearanceConfigurator`. |
| `Sources/AulaF75MaxDriver/AppViewModel.swift` | `batteryStatusColor` fix only. |
| `Sources/AulaF75MaxDriver/Resources/*.lproj/Localizable.strings` | New keys, 7 languages. |
| `.gitignore` | Add `.superpowers/`. |

Porting source: the old views are deleted in Task 1. Later tasks copy behaviour from `git show HEAD:Sources/AulaF75MaxDriver/ContentView.swift` (the version before this plan), with line ranges given per task.

**Note on tests:** the package has no Swift test target, and the spec does not ask for one. Each task's automated check is `make macos-build` plus `python3 scripts/checks/check_localization.py`. Behaviour is checked by running the app (`make macos-app`, then `open "build/Aula F75 Max Driver.app"`) with the steps listed in each task.

---

### Task 1: Shell, sidebar, status bar, shared components

**Files:**
- Create: `scripts/checks/check_localization.py`
- Create: `Sources/AulaF75MaxDriver/Views/SidebarPage.swift`
- Create: `Sources/AulaF75MaxDriver/Views/Components.swift`
- Create: the 7 page files, each a placeholder for now: `HomeView.swift`, `LightingView.swift`, `ScreenView.swift`, `PerformanceView.swift`, `SettingsView.swift`, `DiagnosticsView.swift`, `ActivityLogView.swift`
- Rewrite: `Sources/AulaF75MaxDriver/ContentView.swift` (delete all 938 old lines, including `AppBackground`, `StatusPill`, `StatusCard`, `Panel`, `ActionHeader`, `SectionDivider`, `LanguageSelector`)
- Modify: `Sources/AulaF75MaxDriver/AulaF75MaxDriverApp.swift`
- Modify: `Sources/AulaF75MaxDriver/AppViewModel.swift:104-107`
- Modify: `.gitignore`, all 7 `Localizable.strings`

**Interfaces:**
- Produces:
  - `enum SidebarPage: String, CaseIterable, Identifiable, Hashable` with cases `home, lighting, screen, performance, settings, diagnostics, activityLog`; `var id: String`; `var title: String` (localised via `L10n.text`); `var systemImage: String`; `var isAdvanced: Bool` (true for `diagnostics`, `activityLog`); `static var mainPages: [SidebarPage]`; `static var advancedPages: [SidebarPage]`.
  - `enum DeviceRequirement { case usbCable, receiver }`
  - `struct DeviceRequirementNote: View` with `init(_ requirement: DeviceRequirement)`. Reads `model` from the environment. Renders nothing when the device is present. When missing, shows a warning icon + one sentence: usbCable → "Connect the keyboard with a USB-C cable to use these controls."; receiver → "Plug in the 2.4G receiver to use these controls."
  - `struct StatusBar: View` with `init(selection: Binding<SidebarPage?>)`. While `model.isWorking`: small `ProgressView` + "Working…". Otherwise `model.logLines.last` with `.lineLimit(1)` and `.truncationMode(.tail)`, or "No activity yet" when empty. Clicking it sets `selection = .activityLog`.
  - `struct LogTextView: View` with `init(lines: [String])`. Monospaced, selectable (`.textSelection(.enabled)`), one `Text` joined by `"\n"`, auto-scrolls to bottom on new lines (port from old lines 516-539). Shows "No log entries yet." when empty. No fixed height; callers set it.
  - `struct EndpointGroup: View` and `struct EndpointRow: View`: same initialisers as old lines 709-817, restyled with system colours.
  - Each page: `struct XxxView: View` with no-argument `init()`, except `HomeView(selection: Binding<SidebarPage?>)` and `DiagnosticsView()`.
  - `ContentView` holds `@State private var selection: SidebarPage? = .home`.

- [ ] **Step 1: Write the localisation check**

`scripts/checks/check_localization.py`, run with `python3 scripts/checks/check_localization.py` from the repo root, no arguments.
- Scans `Sources/AulaF75MaxDriver/ContentView.swift` and `Sources/AulaF75MaxDriver/Views/*.swift`, plus `title` strings in `SidebarPage.swift`, for keys matching `L10n\.(?:text|format)\("((?:[^"\\]|\\.)*)"`.
- For each `Sources/AulaF75MaxDriver/Resources/*.lproj/Localizable.strings`, reads keys matching `^"((?:[^"\\]|\\.)*)"\s*=` per line.
- Prints `<lang>: missing "<key>"` for every gap, then `OK: <n> keys in 7 languages` or exits with status 1.

- [ ] **Step 2: Run it against the old UI to see it work**

Run: `python3 scripts/checks/check_localization.py`
Expected: it runs and reports either OK or a list of existing gaps. (en has 201 lines and the others 180, so some gaps are likely. Note them; Step 8 fixes any that the new UI still uses.)

- [ ] **Step 3: Add `SidebarPage`, `Components.swift`, and the 7 placeholder pages**

Values for `SidebarPage`:

| case | title key | systemImage |
|------|-----------|-------------|
| home | "Home" | `house` |
| lighting | "Lighting" | `sparkles` |
| screen | "Screen" | `display` |
| performance | "Performance" | `speedometer` |
| settings | "Settings" | `gearshape` |
| diagnostics | "Diagnostics" | `stethoscope` |
| activityLog | "Activity Log" | `list.bullet.rectangle` |

Each placeholder page: a `Form` with `.formStyle(.grouped)` and `.navigationTitle(SidebarPage.x.title)`, holding one `Text` with the page title. Later tasks replace the body.

- [ ] **Step 4: Rewrite `ContentView`**

- `NavigationSplitView` with sidebar `List(selection: $selection)`: an untitled `Section` with `SidebarPage.mainPages`, then `Section(L10n.text("Advanced"))` with `advancedPages`. Each row: `Label(page.title, systemImage: page.systemImage).tag(page)`.
- Sidebar footer via `.safeAreaInset(edge: .bottom)` on the `List`: "Ready" with a green dot, or a small `ProgressView` + "Working…" while `model.isWorking`.
- Sidebar width: `.navigationSplitViewColumnWidth(min: 180, ideal: 200)`.
- Detail: `switch selection` → the page view (`nil` falls back to `HomeView`), with `StatusBar(selection: $selection)` attached via `.safeAreaInset(edge: .bottom)`.
- Put `.id(model.selectedLanguageCode)` on the sidebar `List` and on the detail content, **not** on the `NavigationSplitView`, so a language change redraws labels but keeps `selection`.
- Keep `.onAppear { model.startMonitoring() }`.

- [ ] **Step 5: Window and app changes**

In `AulaF75MaxDriverApp.swift`: delete `WindowAppearanceView` and `WindowAppearanceConfigurator` and the `.background(...)` that uses them; change `.windowResizability(.contentSize)` to `.windowResizability(.contentMinSize)`; add `.defaultSize(width: 900, height: 600)`. In `ContentView`, set `.frame(minWidth: 760, minHeight: 520)` on the root.

- [ ] **Step 6: Colour fix and gitignore**

`AppViewModel.batteryStatusColor`: replace `.white.opacity(0.42)` with `.secondary`. Append `.superpowers/` to `.gitignore`.

- [ ] **Step 7: Build**

Run: `make macos-build`
Expected: build succeeds, no errors. Warnings about unused localisation keys are fine.

- [ ] **Step 8: Add new keys to all 7 lproj files**

New keys in this task: the 7 page titles, "Advanced", "Ready", "Working…", "No activity yet", the two `DeviceRequirementNote` sentences. Add each to `en.lproj` (value = key) and a drafted translation to es, kk, pt, ru, uz, zh-Hans. Also fill any gaps from Step 2 for keys the new UI uses.

Run: `python3 scripts/checks/check_localization.py`
Expected: `OK: <n> keys in 7 languages`

- [ ] **Step 9: Run the app and check the shell**

Run: `make macos-app && open "build/Aula F75 Max Driver.app"`
Expected:
- The window has red/yellow/green buttons, a sidebar with 5 main pages and an "Advanced" group of 2, and Home selected.
- Clicking each row shows its placeholder title.
- The window resizes, stopping at about 760 × 520.
- Review Focus 3: with an empty log, the status bar reads "No activity yet". Click it: Activity Log is selected.
- macOS appearance switched between Light and Dark: all text stays readable.

- [ ] **Step 10: Pause for review**

Show the owner `git status` and `git diff --stat`, explain the shell structure, and wait. Commit only if the owner says so; message suggestion `feat: replace single-scroll UI with sidebar shell`, no AI co-author.

---

### Task 2: Home page

**Files:**
- Modify: `Sources/AulaF75MaxDriver/Views/HomeView.swift`
- Modify: all 7 `Localizable.strings`

**Interfaces:**
- Consumes: `SidebarPage`, `DeviceRequirementNote` (Task 1); `model.isWiredDevicePresent`, `model.isDonglePresent`, `model.batteryPercent`, `model.batteryStatusColor`, `model.queryBattery()`, `model.syncTime()`, `model.isWorking`.
- Produces: `HomeView(selection: Binding<SidebarPage?>)`.

- [ ] **Step 1: Build the summary card**

At the top, a `GroupBox` or rounded card holding:
- `Image(systemName: "keyboard")`, large, and the name "Aula F75 Max".
- Two status rows:
  - USB: "USB cable connected" (green dot) or "USB cable not connected" (orange dot).
  - Receiver: "2.4G receiver connected" or "2.4G receiver not connected".
- On the right, the battery `"\(percent)%"` in `.system(size: 34, weight: .bold, design: .rounded)` with `.monospacedDigit()` and `.foregroundStyle(model.batteryStatusColor)`. Show "--" when the value is nil.
- A small "Refresh battery" button (`arrow.clockwise`) calling `model.queryBattery()`, disabled when `model.isWorking || !model.isDonglePresent`.

- [ ] **Step 2: Build the quick-action row**

Three equal tiles in an `HStack`:
1. **Screen clock**: caption "Set the keyboard clock to this Mac's time". Button "Sync Clock" calls `model.syncTime()`. Disabled when `model.isWorking || !model.isWiredDevicePresent`. When the cable is missing, the caption reads "Needs the USB cable".
2. **Lighting**: caption "Effects, colour and brightness". Clicking the tile sets `selection = .lighting`. It shows no current values; see the spec's "Home tiles" section.
3. **Screen image**: caption "Show a picture or GIF on the keyboard display". Clicking sets `selection = .screen`.

- [ ] **Step 3: Keys, check, build**

Add every new key to all 7 lproj files (drafted translations).
Run: `python3 scripts/checks/check_localization.py && make macos-build`
Expected: `OK: …` then a successful build.

- [ ] **Step 4: Run and check**

Run: `make macos-app && open "build/Aula F75 Max Driver.app"`
Expected:
- With the receiver plugged in, the battery shows a percentage within a few seconds (startup refresh).
- With nothing plugged in, both rows say "not connected", the battery shows "--", and Sync Clock and Refresh are disabled.
- The Lighting and Screen image tiles switch the sidebar selection.

- [ ] **Step 5: Pause for review** (as Task 1 Step 10; suggested message `feat: add Home page`)

---

### Task 3: Lighting page

**Files:**
- Modify: `Sources/AulaF75MaxDriver/Views/LightingView.swift`
- Modify: all 7 `Localizable.strings`

**Interfaces:**
- Consumes: `DeviceRequirementNote(.receiver)`; `model.rgbMode`, `rgbBrightness` (1...5), `rgbSpeed` (1...5), `rgbDirection` (0...3), `rgbColorful`, `rgbColor`, `model.applyRGB()`; `WirelessAulaLabels.rgbModes`, `WirelessAulaLabels.directionTitle(_:)`.
- Port from: old `ContentView.swift` lines 292-336.

- [ ] **Step 1: Build the form**

`Form` (`.formStyle(.grouped)`), `DeviceRequirementNote(.receiver)` at the top, then one `Section` with these rows:
- **Effect**: `Picker` (menu style) over `WirelessAulaLabels.rgbModes`.
- **Brightness**: segmented `Picker` with values 1...5.
- **Speed**: segmented `Picker` with values 1...5.
- **Direction**: segmented, 0...3, with labels from `directionTitle`.
- **Colour**: a segmented `Picker` bound to `rgbColorful` with options "Rainbow" (true) and "Single colour" (false). Show a `ColorPicker` row "Colour" bound to `rgbColor` only when `rgbColorful == false`.

Controls are disabled when `model.isWorking || !model.isDonglePresent`. Below the form, a trailing-aligned `.borderedProminent` button "Apply Lighting" calls `model.applyRGB()`, with the same disabled rule. Section footer text: "Changes are sent when you press Apply Lighting."

- [ ] **Step 2: Keys, check, build** (same command and expectation as Task 2 Step 3)

- [ ] **Step 3: Run and check**

With the receiver connected:
- Choose an effect, brightness 2, Single colour red, then Apply.
- The keyboard changes, and the status bar shows the RGB success line from the log.
- Changing a control without pressing Apply changes nothing on the keyboard.

- [ ] **Step 4: Pause for review** (`feat: add Lighting page`)

---

### Task 4: Screen page

**Files:**
- Modify: `Sources/AulaF75MaxDriver/Views/ScreenView.swift`
- Modify: all 7 `Localizable.strings`

**Interfaces:**
- Consumes: `DeviceRequirementNote(.usbCable)`; `model.syncTime()`, `chooseFile()`, `selectedFile`, `selectedFileName`, `slot` (1...255), `fitMode` / `ScreenFitMode.allCases`, `progress`, `uploadSelectedImage()`.
- Port from: old lines 106-187, and `uploadProgressText` at lines 544-549. Move that helper into `ScreenView` as a private computed property.

- [ ] **Step 1: Build the form**

`Form` with `DeviceRequirementNote(.usbCable)` at the top, then two sections:
- **Clock**: a row with the label "Keyboard clock", the footer "Sets the screen clock to this Mac's time.", and a "Sync Clock" button.
- **Picture**:
  - "Choose File…" button, with the file name next to it (secondary style when nothing is chosen).
  - "Slot" `Stepper` (1...255).
  - "Fit" segmented picker.
  - A progress row (`ProgressView(value:)` + `uploadProgressText`) shown only while `model.progress.totalChunks > 0`.
  - A `.borderedProminent` "Upload to Keyboard" button.
  - Footer: "PNG, JPEG, GIF, BMP, TIFF or WebP. Shown at 128 × 128."

The disabled rules are exactly the old ones: all controls need `!model.isWorking && model.isWiredDevicePresent`, and Upload also needs `model.selectedFile != nil`.

- [ ] **Step 2: Keys, check, build** (as before)

- [ ] **Step 3: Run and check, including Review Focus 5**

With the USB cable connected:
- Sync Clock works, and the keyboard clock matches the Mac.
- Choose a GIF and upload it. While it uploads, switch to Lighting. The status bar and sidebar footer show "Working…" and the Lighting controls are disabled.
- Back on Screen, the progress bar has advanced. When the upload finishes, the status bar shows the "Uploaded … frame(s) to slot …" line.

- [ ] **Step 4: Pause for review** (`feat: add Screen page`)

---

### Task 5: Performance page

**Files:**
- Modify: `Sources/AulaF75MaxDriver/Views/PerformanceView.swift`
- Modify: all 7 `Localizable.strings`

**Interfaces:**
- Consumes: `DeviceRequirementNote(.receiver)`; `model.keyResponseLevel` (1...5), `sleepTime` (0...3), `applyPerformance()`, `gameModeEnabled`, `setGameMode(_:)`, `restoreCommandKey()`; `WirelessAulaLabels.keyResponseTitle(_:)`, `sleepTitle(_:)`.
- Port from: old lines 340-393.

- [ ] **Step 1: Build the form**

`Form` with `DeviceRequirementNote(.receiver)`, then:
- **Typing** section: a "Key response" menu picker and a "Sleep after" segmented picker. Footer: "Changes are sent when you press Apply." A trailing "Apply" button calls `applyPerformance()`.
- **Game Mode** section: footer "Locks the Command (⌘) key so it can't interrupt games. Also sends the Typing settings above." Contains:
  - A button: "Enable Game Mode" (`gamecontroller`) when `!gameModeEnabled`, or "Disable Game Mode" (`lock.open`) when enabled. It calls `model.setGameMode(!model.gameModeEnabled)`.
  - A "Restore Command Key" button calling `restoreCommandKey()`.

All controls are disabled when `model.isWorking || !model.isDonglePresent`.

- [ ] **Step 2: Keys, check, build** (as before)

- [ ] **Step 3: Run and check**

With the receiver connected:
- Change Sleep, press Apply, and the status bar shows "Performance set: …".
- Enable Game Mode: ⌘ stops working and the button label flips.
- Disable it: ⌘ works again.

- [ ] **Step 4: Pause for review** (`feat: add Performance page`)

---

### Task 6: Settings page

**Files:**
- Modify: `Sources/AulaF75MaxDriver/Views/SettingsView.swift`
- Modify: all 7 `Localizable.strings`

**Interfaces:**
- Consumes: `model.sortedAvailableLanguages` (`AppLanguage` has `code`, `flag`, `name`), `selectedLanguageCode`, `setLanguage(_:)`, `launchAtLoginEnabled`, `toggleLaunchAtLogin()`, `factoryReset()` (it already shows its own `NSAlert` confirmation), `isWiredDevicePresent`, `isWorking`.
- Port from: old lines 452-506 and 191-205.

- [ ] **Step 1: Build the form**

`Form` with three sections:
- **General**:
  - "Language" menu `Picker`. Its binding's `get` is `model.selectedLanguageCode` and its `set` calls `model.setLanguage`. Each option shows `"\(flag)  \(name)"`, and the `system` entry's name goes through `L10n.text`.
  - "Launch at Login" `Toggle`. Its binding's `get` is `model.launchAtLoginEnabled` and its `set` calls `toggleLaunchAtLogin()`. Footer: "Opens the app when you log in. Works without the keyboard connected."
  - Both are disabled while `model.isWorking`.
- **Danger Zone**:
  - `DeviceRequirementNote(.usbCable)`.
  - Footer: "Clears uploaded screen images and resets keyboard settings changed by this app."
  - A `Button(role: .destructive)` "Factory Reset Keyboard…" calling `model.factoryReset()`, disabled when `model.isWorking || !model.isWiredDevicePresent`.

- [ ] **Step 2: Keys, check, build** (as before)

- [ ] **Step 3: Run and check, including Review Focus 2**

- Switch the language to Русский. The sidebar titles, the page title, all picker options on Lighting and Performance, and the status bar text all change at once, and Settings stays selected.
- Switch back to System default.
- Factory Reset shows the confirmation alert. Press Cancel, and the status bar shows "Factory reset cancelled."

- [ ] **Step 4: Pause for review** (`feat: add Settings page`)

---

### Task 7: Diagnostics and Activity Log pages

**Files:**
- Modify: `Sources/AulaF75MaxDriver/Views/DiagnosticsView.swift`, `Sources/AulaF75MaxDriver/Views/ActivityLogView.swift`
- Modify: all 7 `Localizable.strings`

**Interfaces:**
- Consumes: `EndpointGroup`, `LogTextView`, `DeviceRequirementNote` (Task 1); `model.endpoints`, `wirelessEndpoints`, `manualRefresh()`, `isInputMonitoring`, `toggleInputMonitoring()`, `dumpKeymap()`, `keymapTestPageIndex` (0...8), `keymapTestByteOffset` (0...63), `keymapTestLength` (1...64), `keymapTestValue` (0...255), `testKeymapByteWrite()`, `logLines`.
- Port from: old lines 398-449 (endpoints) and 209-253 (keymap tools).

- [ ] **Step 1: Build `ActivityLogView`**

The `LogTextView(lines: model.logLines)` fills the page, with `.navigationTitle`. A toolbar "Copy" button puts `model.logLines.joined(separator: "\n")` on `NSPasteboard.general`.

- [ ] **Step 2: Build `DiagnosticsView`**

A `ScrollView` (this page may scroll, per the spec) holding a `Form`:
- **Connections**:
  - "Rescan" button and "Start/Stop Input Monitor" button, with the same labels, icons and `.help` text as old lines 412-432.
  - `EndpointGroup` for wired, then `EndpointGroup` for the receiver, keeping the old empty-state text.
- **Keymap Research**, with the footer "For protocol research. Not needed for normal use."
  - `DeviceRequirementNote(.usbCable)`.
  - "Dump Keymap Pages" button.
  - Four `Stepper`s with the old ranges and labels, with Value shown as `0x%02X`.
  - `Button(role: .destructive)` "Write Test Byte…".
    - It does **not** call the model directly. It sets `@State var confirmByteWrite = true`.
    - A `.confirmationDialog` titled "Write to the keyboard?" has the message "This changes keymap data on the keyboard. Factory Reset can undo it."
    - The dialog's destructive "Write" action calls `model.testKeymapByteWrite()`, and its "Cancel" does nothing.
- **Log**: a `LogTextView(lines: model.logLines)` with `.frame(height: 180)`.

The disabled rules are the old ones.

- [ ] **Step 3: Keys, check, build** (as before)

- [ ] **Step 4: Run and check**

- With nothing plugged in, both endpoint groups show their empty states.
- Plug in the receiver: its group fills without a Rescan (Review Focus 1).
- Write Test Byte shows the dialog, and Cancel writes nothing (the log has no "Wrote page" line).
- Start Input Monitor: key presses appear in the embedded log.
- Activity Log shows the same lines, and Copy puts them on the clipboard.

- [ ] **Step 5: Pause for review** (`feat: add Diagnostics and Activity Log pages`)

---

### Task 8: Translation review sheet and final verification

**Files:**
- Create: `docs/superpowers/plans/2026-10-16-ui-redesign-translations.md`

- [ ] **Step 1: Generate the review sheet**

List every key added by Tasks 1-7 in one table: key | en | es | kk | pt | ru | uz | zh-Hans. Take the values from the lproj files rather than retyping them. Hand the sheet to the owner, apply their corrections to the lproj files, then run `python3 scripts/checks/check_localization.py` again.

- [ ] **Step 2: Confirm no old styling survived**

Run: `grep -rnE "\.white|ignoresSafeArea|Avenir|AppBackground|Panel\(" Sources/AulaF75MaxDriver/ContentView.swift Sources/AulaF75MaxDriver/Views/`
Expected: no output.

- [ ] **Step 3: Confirm the packaged binary is fresh**

Run: `make macos-app && strings "build/Aula F75 Max Driver.app/Contents/MacOS/AulaF75MaxDriver" | grep -c "Activity Log"`
Expected: `1` or more. A `0` means a stale binary; do not test hardware with it.

- [ ] **Step 4: Full manual pass on hardware**

Use the USB cable, the receiver, or both, as each check needs:
- Every action from the old UI is reachable: battery query, RGB apply, performance apply, Game Mode on/off, restore ⌘, sync clock, upload, factory reset (cancel), keymap dump, test byte (cancel), input monitor, rescan, language, launch at login.
- Review Focus 1: unplug the cable while on Screen. The note appears and the controls disable. Plug it back in, and they enable again.
- Review Focus 4: switch to Русский, then Қазақша. At the minimum window size, check every page for clipped or overlapping text.
- Light mode and dark mode: every page is readable.

- [ ] **Step 5: Pause for final review**

Show the owner the full `git diff --stat` and the translation sheet, and summarise what changed. Commit or push only on the owner's explicit OK, with no AI co-author.
