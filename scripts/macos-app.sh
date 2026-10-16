#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"
cp "${EXECUTABLE}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp Info.plist "${APP_DIR}/Contents/Info.plist"
cp -R "Sources/AulaF75MaxDriver/Resources/." "${APP_DIR}/Contents/Resources/"

# Clear any inherited quarantine metadata and re-sign the final app bundle.
# This keeps Gatekeeper from treating the copied bundle as a damaged executable.
if command -v xattr >/dev/null 2>&1; then
    xattr -cr "${APP_DIR}"
fi

if command -v codesign >/dev/null 2>&1; then
    # Prefer a stable local signing identity if one is installed (see
    # scripts/macos-setup-local-signing.sh), so macOS privacy grants such as
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
