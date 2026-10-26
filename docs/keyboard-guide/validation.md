# Validation — 2026-10-26

- `make macos-build` and `make macos-app`: passed. The local app bundle is in
  `build/Aula F75 Max Driver.app`.
- `make android-build android-test`: passed; 42 JVM tests, zero failures/errors.
- `python3 scripts/checks/generate_keyboard_guide.py --check`: passed; checks that
  all native catalogs and all seven-language resource sets match the source.
- `python3 scripts/checks/check_localization.py`: passed.
- `git diff --check`: passed.

The actual SwiftUI guide view was rendered in an isolated NSHostingView, using the
app's card style, insets, keycap component and localized resources. The preview
harness did not instantiate the device model. Checked Russian, Spanish (Mac mode),
Kazakh and Chinese at 600 pt content width, plus Russian at 360 pt to verify stacked
rows. A bottom-of-page render checked additional keys, the knob, reset warning and
manual link. Previews are ignored build artifacts:

- `build/keyboard-guide-ru-600.png`
- `build/keyboard-guide-ru-600-bottom.png`
- `build/keyboard-guide-ru-360.png`
- `build/keyboard-guide-es-600.png`
- `build/keyboard-guide-kk-600.png`
- `build/keyboard-guide-zh-Hans-600.png`

## Remaining environment-dependent checks

`make macos-test` could not run: the installed Command Line Tools cannot resolve
XCTest. The successful release build uses the compatible macOS 26.5 SDK selected
by the existing build script. Full XCTest execution requires a working Xcode test
toolchain.

Linux build and GTK integration tests could not run on this macOS host: GTK4 and
hidapi development dependencies are absent, and no Linux Docker daemon is running.
The existing Linux UI test was extended to cover the guide, both reference modes,
narrow-window screenshots and preserved Ctrl+6/7/8 navigation; it runs in the Linux
CI job.

There is no connected Android device or installed emulator for screenshot,
TalkBack or touch-layout checks. Desktop UI automation was unavailable (native
computer-use pipe closed), so full-window navigation and VoiceOver checks remain
manual. The renders above validate the guide content layout, not the app sidebar
or OS accessibility announcements.
