# Development guide

For installation and everyday use, see the [README](../README.md).

## Build and run

Run commands from the repository root. `make help` lists the available targets. Generated output belongs in `.build/`, `build/`, and `android/app/build/` and should not be committed.

### macOS

Requires macOS 14+, an Apple Silicon Mac, and Xcode Command Line Tools or Xcode with a Swift 6 toolchain.

```sh
make macos-build
make macos-app
make macos-run
make macos-dmg
```

These targets respectively build the release arm64 binary, package `build/Aula F75 Max Driver.app`, build and open the app, and create `build/Aula F75 Max Driver.dmg`. The DMG includes an Applications shortcut for drag-to-install.

The build checks SwiftUI support in the selected SDK. If the default Command Line Tools SDK is incomplete (for example, missing `SwiftUIMacros`), it selects the newest compatible installed SDK. To select one explicitly, use `MACOS_SDKROOT=/absolute/path/to/MacOSX.sdk make macos-run`; an explicit selection is never overridden.

Test Launch at Login from the packaged app: it uses ServiceManagement and depends on the app bundle identity. The app is packaged from SwiftPM rather than an Xcode project; it does not include a WidgetKit extension.

### Linux

Build on Linux with Swift 6, GTK4, hidapi, and pkg-config. Ubuntu dependencies:

```sh
sudo apt install libgtk-4-dev libhidapi-dev pkg-config
```

Fedora dependencies for source builds:

```sh
sudo dnf install gtk4-devel hidapi-devel pkgconf-pkg-config
```

```sh
make linux-build
make linux-install-udev
make linux-run
```

The udev installation requires administrator access. Replug the keyboard and receiver afterward. The rule is maintained in [packaging/linux](../packaging/linux/60-aula-f75-max.rules).

`make linux-deb` builds a Debian/Ubuntu installer in `build/`. It installs the launcher, desktop entry, icon, required Swift runtime libraries, and udev rule. See [the packaging script](../scripts/linux-deb.sh) for packaging dependencies and architecture handling. `make linux-package` produces the legacy developer archive `build/AulaF75MaxDriverLinux.tar.gz`.

### Android

Requires JDK 17 and the Android SDK. CI installs platform-tools, Android platform 34, and build-tools 34.0.0. The minimum device version is Android 9 (API 28). Android Studio is optional.

```sh
make android-build
make android-test
adb install -r android/app/build/outputs/apk/debug/app-debug.apk
```

The project uses its checked-in Gradle wrapper; downloaded Gradle state is kept under `android/.gradle/`. Hardware checks require USB OTG and USB Host permission.

`make clean` removes `.build/` and `build/`; it does not clean Android output.

## Project structure and data flow

- `Sources/AulaCore/` contains portable Swift packet builders, keyboard geometry, lighting settings, and preview rendering shared by macOS and Linux.
- `Sources/AulaF75MaxDriver/` contains the SwiftUI app, AppKit integrations, IOKit HID transport, display encoder, notifications, and login helper.
- `Sources/AulaLinuxApp/`, `Sources/AulaLinuxHID/`, and `Sources/CAulaLinuxGTK/` provide the GTK4 UI, hidapi/hidraw transport, and C bridge.
- `android/` is a separate Kotlin/Compose Gradle project using the Android USB Host API.
- `site/` contains the static website and screenshots; `docs/` contains developer documentation, validation reports, and design plans. `assets/app-icon.png` is the shared source icon used by the README, Linux packaging, and website build.
- `Package.swift` defines the Swift targets; `Info.plist` configures the macOS app bundle. `Makefile`, `make/`, and `scripts/` provide build and packaging commands.

On macOS, `AulaF75MaxDriverApp` creates `AppViewModel`; views invoke its actions and render published state. The view model coordinates HID monitoring, device operations, battery polling, and logs. `AulaDevice` handles wired commands, `WirelessAulaDevice` handles the receiver, and `DisplayEncoder` prepares display payloads. Device work runs off the main actor where appropriate.

On Android, `AulaViewModel` coordinates the UI, `AndroidAulaBackend` performs commands, and `UsbHidSession` claims USB interfaces after permission is granted.

### Profiles, previews, and localization

macOS lighting profiles use UserDefaults key `lighting.profiles.v1`. Linux uses `$XDG_CONFIG_HOME/aula-f75-max-driver/lighting-profiles.json`, defaulting to `~/.config/aula-f75-max-driver/lighting-profiles.json`. Android stores profile JSON in private SharedPreferences under `lighting.profiles.v1`. Profiles are local to each installation and independent of firmware.

Lighting edits change the preview until Apply. Selecting a saved profile can also apply it when the receiver is connected, permitted, and idle. Android does not defer automatic application until a receiver connects. Desktop Revert restores the last applied settings. Home displays the last successfully applied lighting in the current session.

Desktop screen previews show encoded RGB565 frames, GIF timing, thumbnails, and upload progress. Android shows the first GIF frame in its preview. Android lighting animation pauses off screen and in the background and respects the system animator-duration setting.

macOS and Linux bundle English, Russian, Spanish, Uzbek, Kazakh, Portuguese, and Simplified Chinese. Their language selection uses UserDefaults key `app.language.code`. Android bundles English and Russian, stores its choice in SharedPreferences, and falls back to English for unsupported system locales.

## Device protocol

| Endpoint | Vendor / product | Usage page |
| --- | --- | --- |
| Wired command | `0x0c45` / `0x800a` | `0xff13` |
| Wired raw display | `0x0c45` / `0x800a` | `0xff68` |
| Receiver command | `0x05ac` / `0x024f` | `0xff59` |
| Receiver raw | `0x05ac` / `0x024f` | `0xff60` |

Endpoint selection also uses report-size heuristics where needed. Wired USB handles display uploads, clock sync, and reset; the receiver handles battery, lighting, response level, sleep, Game Mode, and Command key restore.

Display uploads render supported image files to 128 × 128 pixels, encode RGB565 frames, and send chunks in 4096-byte HID output reports. Display slots range from 1 through 255. Fit preserves aspect ratio with letterboxing, Fill crops while preserving aspect ratio, and Stretch fills the display without preserving proportions. Animated GIF uploads retain frame delays.

The protocol follows observed/public packet flows and may need changes for firmware variants. Actual transport behavior requires hardware verification. The apps communicate from user space and do not install kernel extensions. Do not commit pairing data, device secrets, signing credentials, or private diagnostic captures.

## Testing

The current Swift manifest defines shared `AulaCoreTests` and macOS-only `AulaF75MaxDriverTests` under `Tests/`.

```sh
swift test
swift test --filter LightingPreviewTests
make android-test
```

The Swift suites cover shared behavior and, on macOS, keyboard geometry, lighting, profiles, and screen preview decoding. Android JVM tests live under `android/app/src/test/`.

On Linux, run:

```sh
bash scripts/linux-ui-test.sh
```

This exercises GTK widgets using mocked HID, isolated profiles, image/GIF fixtures, and temporary screenshots and recordings. It requires `xvfb`, `xauth`, `ffmpeg`, a C compiler, and GTK development dependencies. It covers profile CRUD, failed Apply and Revert, preview/upload consistency, GIF timing, progress, reduced animation, and closing during background preparation. It sends no commands to physical hardware.

For release validation, build the appropriate platform artifacts with `make macos-app`, `make linux-deb`, or `make android-build` and manually check:

- Device detection over wired USB and the receiver, including reconnection.
- Battery readings and a harmless lighting change through the receiver.
- Clock sync and a small image/GIF upload to a non-critical slot over USB.
- Language changes and any changed platform integration, such as Launch at Login.
- Android OTG permission and the corresponding wired/receiver actions.

macOS may require Input Monitoring permission. Linux needs hidraw access through udev; Android needs USB Host permission.

## Website and releases

The static user site starts at [site/index.html](../site/index.html), with platform guides, screenshots, and seven site languages. English is the default.

Build and preview it from the repository root:

```sh
make site-build
python3 -m http.server --directory build/site
```

Open http://localhost:8000 in a browser. The build replaces only `build/site/`, copies all website files (including hidden files), and adds the shared icon as `assets/app-icon.png`. Preview the built directory so the icon is available. Generated copies should not be committed.

The [Pages workflow](../.github/workflows/pages.yml) builds and publishes only `build/site/` on pushes to `main` or `master` and supports manual dispatch. Developer documentation and plans are excluded; public page and asset URLs remain unchanged.

The [build workflow](../.github/workflows/build.yml) builds the macOS DMG, Linux DEB, and Android debug APK and runs Android tests on pushes and pull requests. Tagged builds also produce the signed Android release APK and create or update a GitHub release. The workflow also runs portable Swift tests and Linux UI checks.

Before tagging an Android release, configure repository secrets:

- `ANDROID_RELEASE_KEYSTORE_BASE64`
- `ANDROID_RELEASE_KEYSTORE_PASSWORD`
- `ANDROID_RELEASE_KEY_ALIAS`
- `ANDROID_RELEASE_KEY_PASSWORD`

Keep an offline backup of the signing key and passwords. Updates must use the same signing key as the installed app. The workflow requires all signing secrets and verifies the APK with `apksigner` before publication.

`make release-package` prepares versioned assets from existing build artifacts, using `RELEASE_DIR`, `RELEASE_TAG`, `SOURCE_MACOS_DMG`, `SOURCE_ANDROID_APK`, and `SOURCE_LINUX_DEB`. See the workflow for a complete invocation. Published files use the `AulaF75MaxDriver-v<version>` base name; DEBs also include the architecture. Alpha, beta, and RC tags are marked as prereleases and are not made latest.

### Update channels

All three apps check this repository's public GitHub Releases API. Settings offer
**Stable** (full releases) and **Alpha** (full releases plus alpha, beta, and RC).
The initial channel follows the installed build; an explicit choice persists.
Automatic checks run while the app is open, at launch/activation after 24 hours.
Failed automatic checks wait at least an hour before retrying. Manual checks and
channel changes check immediately, subject to GitHub's rate-limit backoff.
The API cache stores ETags and pagination links; no GitHub token is bundled.

The Update button downloads and installs through the platform installer:

- macOS uses Sparkle 2.10.0, with signed appcasts and Ed25519-signed DMGs. Sparkle
  presents download/install progress and replaces/relaunches the app. Relaunch
  waits for any active keyboard operation to finish.
- Android downloads into private cache, checks package ID, version code, release
  version, SHA-256 when provided, and the installed app's signing certificate.
  A narrowly scoped FileProvider grants the system installer access. Android
  asks the user to allow installation from this app and confirm the update.
  Debug APKs cannot update to the release APK because their signing keys differ.
- Linux checks the GitHub asset SHA-256 and DEB package name, architecture and
  version before asking PackageKit to install it. Desktop PolicyKit handles
  authorization. `packagekit` is recommended by the DEB; a missing service or
  rejected authorization produces an error with retry. Restart is explicit and
  disabled while a keyboard operation is running.

Checks and downloads do not send keyboard commands. Switching from Alpha to
Stable waits for a newer full release instead of downgrading. Dismissed banners
stay hidden for that version; Settings still offers installation. Older releases
without a signed appcast (macOS) or a SHA-256 asset digest (Linux) cannot be
installed in-app. The first app version containing this updater must be installed
through the existing distribution path.

Use tags `vX.Y.Z`, `vX.Y.Z-alpha.1`, `vX.Y.Z-beta.1`, `vX.Y.Z-rc.1`, or the legacy
`vX.Y.Z-rc1`. CI marks all preview formats as prereleases and leaves Latest on
the stable channel. The updater selects the highest supported version with a
matching release asset: macOS arm64 DMG, Linux architecture-specific DEB, or APK.
Publish all platform assets before announcing a release.

CI resolves `AULA_RELEASE_VERSION` through `scripts/build-version.py`. macOS stores
the full string as `AulaReleaseVersion` and numeric components in its standard
bundle metadata. Linux stores `version.txt` alongside its executable and uses
`~alpha.1`/`~beta.1`/`~rc.1` in Debian package versions. Android uses the release
string as `versionName` and the Build workflow run number as `versionCode`.
Keep this workflow's run counter increasing; any replacement workflow must seed
a version code higher than all published APKs. Rerunning a build keeps its code.
Local/branch builds use `0.1.0+dev.<sha>` (Android local builds: `0.1.0+dev`);
build metadata is ignored when comparing versions.

Tests use fixture responses and never publish releases. Run `swift test`,
`make android-test`, and `bash scripts/linux-ui-test.sh` on their supported hosts.
After publishing, manually verify a real update from the preceding release on
all platforms, including download links, signing compatibility, and channel choice.

### Sparkle release signing

The public key is versioned in `packaging/macos/sparkle-public-key.txt` and copied
into `SUPublicEDKey` during packaging. The private key is stored in the macOS login
Keychain under account `VitalyArt.AulaF75MaxDriver` and GitHub Actions secret
`SPARKLE_PRIVATE_KEY`. Never put the private key in the repository or artifacts.
Use Sparkle's `generate_keys --account VitalyArt.AulaF75MaxDriver -x <secure-file>`
to make an offline backup outside the checkout. Keep this key stable across builds.

The macOS job signs the DMG and per-release appcast with `scripts/macos-appcast.py`.
The release job stores the signed XML in the `sparkle-feeds` data branch using
`scripts/publish-update-feed.sh`. Only DMG, APK and DEB installers are attached to
new GitHub Releases. A dependent job calls the Pages workflow to publish the XML at
`https://vitalyart.github.io/Aula-F75-Max-Driver/updates/macos/<tag>.xml`.
Merge the workflow and app changes into the default branch before tagging a release.

Every Pages deployment builds the website from the default branch and overlays the
complete feed history from `sparkle-feeds` with `scripts/copy-update-feeds.sh`.
This prevents site updates or older release tags from removing feeds or rolling
back the website. Concurrent feed writes retry against the latest data branch;
Pages deployments share one concurrency group. Do not delete the data branch or
its historical XML files. Only signed public metadata belongs in this branch.
GitHub Actions needs Contents write access to this branch and Pages/ID-token write
permissions for deployment. The `github-pages` environment allows release tags matching
`v*`; unprefixed version tags need a corresponding environment rule before use.
Branch rules must allow Actions to update the data branch.

The app selects a release through the GitHub API, then probes its fixed Pages URL.
A 404 offers manual download for older releases; network errors remain errors.
It retains support for legacy appcast assets, including `v1.7.0-rc1`: keep that
release's XML asset. That shipped app only discovers feed assets, so its first
update to a Pages-based release requires manual download. Subsequent updates use
Pages. Do not remove old XML assets during migration.

Sparkle's own scheduling stays disabled to avoid duplicate checks. `SURequireSignedFeed` and `SUVerifyUpdateBeforeExtraction` are enabled.
The embedded Sparkle framework preserves framework symlinks and receives the
same local/code-signing identity as the app. Developer ID notarization remains a
separate distribution configuration.

Run `python3 -m unittest discover -s Tests/Packaging` for appcast tests in addition
to the Swift, Android and GTK suites. Verify a real update across two published,
signed releases on each platform before relying on unattended distribution.
