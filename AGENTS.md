# Repository Guidelines

## Project Structure & Module Organization

This repository ships native macOS, Linux, and Android apps. Shared portable Swift protocol code lives in `Sources/AulaCore/`. The macOS SwiftUI app lives in `Sources/AulaF75MaxDriver/`, with UI, IOKit device protocol, login helper, and display encoding code split across files such as `ContentView.swift`, `AppViewModel.swift`, and `WirelessAulaDevice.swift`. Linux-specific code lives in `Sources/AulaLinuxApp/`, `Sources/AulaLinuxHID/`, and `Sources/CAulaLinuxGTK/`. The Android Kotlin/Compose and USB Host app is a separate Gradle project under `android/`. Package metadata is in `Package.swift`, the macOS app bundle plist is `Info.plist`, and Linux udev rules live under `packaging/linux/`. Build output is written to `build/`, `.build/`, and `android/app/build/`.

## Build, Test, and Development Commands

- `make help`: lists platform-specific Make targets.
- `make macos-build`: builds the macOS SwiftUI app for `arm64` in release mode.
- `make macos-app`: packages `build/Aula F75 Max Driver.app`.
- `make macos-run`: builds the macOS app bundle and opens it in Finder.
- `make macos-dmg`: builds the macOS DMG installer.
- `make linux-build`: builds the native Linux GTK app on Linux.
- `make linux-run`: runs the native Linux GTK app on Linux.
- `make android-build`: builds the Android debug APK with JDK 17 and the Gradle wrapper.
- `make android-test`: runs the Android JVM unit tests.
- `make all`, `make build`, `make app`, `make dmg`, and `make run`: compatibility aliases for the macOS targets.
- `make clean`: removes `.build/` and `build/`.

There is no Swift test target in the current manifest. Android JVM tests live under `android/app/src/test/`.

## Coding Style & Naming Conventions

Use standard Swift and Kotlin style: 4-space indentation, `PascalCase` for types, `camelCase` for methods, properties, and local variables. Keep file names aligned with the main type or feature they contain. Prefer small, focused types over large view or protocol classes. No formatter or linter is configured in this repo, so follow the surrounding code closely.

## Testing Guidelines

No automated Swift tests are currently defined. If you add them, place them under `Tests/` with names like `AulaF75MaxDriverTests.swift`, and use `swift test` once a test target exists. Keep Android JVM tests under `android/app/src/test/` and run them with `make android-test`. Android hardware behavior still requires an Android 9+ device with USB OTG and a connected keyboard or receiver.

## Commit & Pull Request Guidelines

This workspace does not expose usable Git history, so there is no verified commit convention to mirror. Use short, imperative commit messages with a prefix when helpful, such as `feat: add battery polling` or `fix: handle missing HID report`.

Pull requests should describe the user-visible change, list validation steps (`make macos-build`, `make linux-build`, or `make android-test`/`make android-build` where relevant), and include screenshots or screen recordings when the UI changes. Note any hardware, macOS permission, Linux udev, or Android USB Host requirements if the change depends on them.

## Security & Configuration Tips

This app talks to a keyboard over USB and raw HID. Do not commit device secrets, pairing data, signing credentials, or generated build output. Some features may require macOS Input Monitoring permission, Linux udev hidraw access, or Android USB Host permission and a connected Aula F75 Max device for verification.
