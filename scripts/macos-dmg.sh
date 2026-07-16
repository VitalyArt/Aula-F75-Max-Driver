#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

rm -rf "${DMG_DIR}" "${DMG_PATH}" "${DMG_RW_PATH}"
mkdir -p "${DMG_DIR}"
cp -R "${APP_DIR}" "${DMG_DIR}/"
ln -s /Applications "${DMG_DIR}/Applications"

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_DIR}" \
    -ov \
    -fs HFS+ \
    -format UDRW \
    "${DMG_RW_PATH}"

mount_dir="$(mktemp -d "/tmp/${APP_NAME}-dmg.XXXXXX")"
device=""
cleanup() {
    if [ -n "$device" ]; then hdiutil detach "$device" >/dev/null 2>&1 || true; fi
    rm -rf "$mount_dir"
}
trap cleanup EXIT

device="$(
    hdiutil attach "${DMG_RW_PATH}" -readwrite -noverify -noautoopen -owners off -mountpoint "$mount_dir" \
        | awk '/^\/dev\// { print $1; exit }'
)"
osascript "${DMG_STYLE_SCRIPT}" "$mount_dir" "${APP_NAME}"
sync
hdiutil detach "$device"
device=""

hdiutil convert "${DMG_RW_PATH}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_PATH}"
rm -f "${DMG_RW_PATH}"

if [ -n "${NOTARYTOOL_PROFILE:-}" ]; then
    if ! command -v xcrun >/dev/null 2>&1; then
        printf '%s\n' 'xcrun is required for notarization but was not found'
        exit 1
    fi

    xcrun notarytool submit "${DMG_PATH}" \
        --keychain-profile "${NOTARYTOOL_PROFILE}" \
        --wait \
        --timeout "${NOTARYTOOL_TIMEOUT}"
    xcrun stapler staple "${DMG_PATH}"
fi
