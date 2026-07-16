#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"
cp "${EXECUTABLE}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp Info.plist "${APP_DIR}/Contents/Info.plist"
cp "Sources/AulaF75MaxDriver/Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"

# Clear any inherited quarantine metadata and re-sign the final app bundle.
# This keeps Gatekeeper from treating the copied bundle as a damaged executable.
if command -v xattr >/dev/null 2>&1; then
    xattr -cr "${APP_DIR}"
fi

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - --timestamp=none "${APP_DIR}"
fi
