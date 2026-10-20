# Android validation — 2026-10-20

Device: Samsung SM-S936B, 1080 × 2340, density 450. Tested through wireless ADB using a separate **Aula F75 Max Preview** installation (`com.vitalyart.aulaf75maxdriver.preview`) to preserve the existing application's data and signing identity. The test name and application ID came from temporary Gradle/manifest overlays; the normal APK was rebuilt afterward.

## Interface and profiles

Verified Home keyboard geometry and two-tone keycaps; animated RGB preview; wrapping effect tiles and selected styling; profile creation, persistence across force-stop/relaunch, selection, deletion confirmation and deletion; landscape navigation rail; and the Display page at 150% font scale. Fixed dark-text contrast on Home and unselected effect tiles during device testing.

Screenshots: [Home](screenshots/android-home.png), [Lighting](screenshots/android-lighting.png).

Profile rename/update, unsaved-edit confirmation, reduced-motion behavior, GIF uploads, and physical-tablet layout still require device-level verification. JVM tests cover preview/model behavior, profile persistence and HID descriptor parsing.

## Receiver lighting

The phone enumerated `05AC:024F` (`2.4G Dongle`). Actual HID descriptors identify interface 3 as `0xFF60` (raw, interrupt endpoint 5, 32-byte reports) and interface 4 as `0xFF59` (command, 64-byte reports).

Android selects the raw Usage Page explicitly and uses synchronous endpoint transfers. The [Android/Linux USBDEVFS_BULK path](https://android.googlesource.com/kernel/common/+/91b1ad0815fbb1095c8b9e8a2bf4201186afe304/drivers/usb/core/devio.c) supports interrupt endpoints as well. This avoids the native request-wait crash observed with an intermediate asynchronous implementation, which was removed.

Both 32-byte RGB reports transmitted in full. The application remained running, and the owner confirmed that Apply changes the physical keyboard lighting. USB writes completing alone are not treated as proof of physical behavior. Errors appear beside Apply, and backend operations are serialized to avoid competing interface claims.

## Wired image upload

The phone enumerated `0C45:800A` (`AULA F75Max`). Actual descriptors identify interface 3 as `0xFF13` (64-byte command/feature reports) and interface 2 as `0xFF68` (4096-byte Output reports, 64-byte Input reports and USB interrupt packets).

Display selection uses HID Usage Page rather than USB packet size. Discovery stops at the requested interface so opening the display channel does not claim/release the command channel already in use. Input buffers use HID report lengths. Display chunks use synchronous interrupt OUT, while commands retain feature SET_REPORT/GET_REPORT.

A one-frame JPEG uploaded to slot 1: all nine 4096-byte blocks and the final 64-byte command completed. The app displayed **Image uploaded successfully**, and the owner confirmed that the picture appeared on the keyboard. Errors and missing wired-device permissions appear directly on the Display page.

## Build and cleanup

`make android-test` and `make android-build` passed, with out-of-process Kotlin compilation and incremental compilation disabled for this machine's JDK 25 daemon. These overrides were supplied only to the local commands; no JDK/toolchain changes are included.

Original portrait rotation, 100% font scale and 30-second screen timeout were restored. Temporary stay-awake behavior was disabled; the temporary test profile was deleted.
