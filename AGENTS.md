# Repository Guidelines

## Project Structure & Module Organization

This is a Swift Package for a macOS app. Core source lives in `Sources/AulaF75MaxDriver/`, with UI, device protocol, login helper, and display encoding code split across files such as `ContentView.swift`, `AppViewModel.swift`, and `WirelessAulaDevice.swift`. Package metadata is in `Package.swift`, and the app bundle plist is `Info.plist`. Build output is written to `build/` and `.build/`.

## Build, Test, and Development Commands

- `make all`: builds the app for `arm64` in release mode and packages `build/Aula F75 Max Driver.app`.
- `make build`: runs `swift build -c release --arch arm64`.
- `make run`: builds the app bundle and opens it in Finder.
- `make clean`: removes `.build/` and `build/`.

There is no test target in the current manifest.

## Coding Style & Naming Conventions

Use standard Swift style: 4-space indentation, `PascalCase` for types, `camelCase` for methods, properties, and local variables. Keep file names aligned with the main type or feature they contain. Prefer small, focused types over large view or protocol classes. No formatter or linter is configured in this repo, so follow the surrounding code closely.

## Testing Guidelines

No automated tests are currently defined. If you add them, place them under `Tests/` with names like `AulaF75MaxDriverTests.swift`, and keep test names descriptive of behavior. Use `swift test` once a test target exists, or add an Xcode test scheme if you move the project into an app workspace.

## Commit & Pull Request Guidelines

This workspace does not expose usable Git history, so there is no verified commit convention to mirror. Use short, imperative commit messages with a prefix when helpful, such as `feat: add battery polling` or `fix: handle missing HID report`.

Pull requests should describe the user-visible change, list validation steps (`make build`, manual device check), and include screenshots or screen recordings when the UI changes. Note any hardware or macOS permission requirements if the change depends on them.

## Security & Configuration Tips

This app talks to a keyboard over USB and raw HID. Do not commit device secrets, pairing data, or generated build output. Some features may require macOS Input Monitoring permission and a connected Aula F75 Max device for verification.
