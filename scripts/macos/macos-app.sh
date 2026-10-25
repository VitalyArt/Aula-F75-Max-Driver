#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"
cp "${EXECUTABLE}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp Info.plist "${APP_DIR}/Contents/Info.plist"
release_version="${AULA_RELEASE_VERSION:-$(python3 scripts/release/build-version.py)}"
/usr/libexec/PlistBuddy -c "Add :AulaReleaseVersion string ${release_version}" "${APP_DIR}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${release_version%%[-+]*}" "${APP_DIR}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${GITHUB_RUN_NUMBER:-1}" "${APP_DIR}/Contents/Info.plist"
sparkle_framework=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [[ ! -d "$sparkle_framework" ]]; then
    printf '%s\n' 'Sparkle.framework is missing; run the macOS build first.' >&2
    exit 1
fi
mkdir -p "${APP_DIR}/Contents/Frameworks"
ditto "$sparkle_framework" "${APP_DIR}/Contents/Frameworks/Sparkle.framework"
public_key="$(tr -d '\r\n' < packaging/macos/sparkle-public-key.txt)"
/usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string ${public_key}" "${APP_DIR}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :SUEnableAutomaticChecks bool false" "${APP_DIR}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :SUAutomaticallyUpdate bool false" "${APP_DIR}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :SUVerifyUpdateBeforeExtraction bool true" "${APP_DIR}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :SURequireSignedFeed bool true" "${APP_DIR}/Contents/Info.plist"
cp -R "Sources/AulaF75MaxDriver/Resources/." "${APP_DIR}/Contents/Resources/"

# Clear any inherited quarantine metadata and re-sign the final app bundle.
# This keeps Gatekeeper from treating the copied bundle as a damaged executable.
if command -v xattr >/dev/null 2>&1; then
    xattr -cr "${APP_DIR}"
fi

if command -v codesign >/dev/null 2>&1; then
    # Prefer a stable local signing identity if one is installed (see
    # a locally installed signing certificate), so macOS privacy grants such as
    # Input Monitoring survive rebuilds instead of resetting every time, as
    # they do with the content-hashed ad-hoc identity ("-"). Falls back to
    # ad-hoc signing when no such identity exists, e.g. in CI.
    codesign_identity="${CODESIGN_IDENTITY:-}"
    if [[ -z "${codesign_identity}" ]]; then
        # Deliberately omit -v here: it filters to identities macOS's trust
        # policy fully validates, which excludes our self-signed local cert
        # (it shows CSSMERR_TP_NOT_TRUSTED) even though codesign accepts it
        # fine for local signing.
        if security find-identity -p codesigning 2>/dev/null | grep -q "Aula F75 Max Driver Local Dev"; then
            codesign_identity="Aula F75 Max Driver Local Dev"
        else
            codesign_identity="-"
        fi
    fi
    codesign --force --deep --sign "${codesign_identity}" --timestamp=none "${APP_DIR}"
fi
