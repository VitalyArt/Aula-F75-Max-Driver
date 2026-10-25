#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
: "${ANDROID_KEYSTORE_PASSWORD:?Release keystore password is required}"
: "${ANDROID_KEY_ALIAS:?Release key alias is required}"
: "${ANDROID_KEY_PASSWORD:?Release key password is required}"
if [[ -n "${ANDROID_KEYSTORE_BASE64:-}" ]]; then
    key_dir="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/aula-signing.XXXXXX")"
    trap 'rm -rf "$key_dir"' EXIT
    export ANDROID_KEYSTORE_PATH="$key_dir/release.jks"
    python3 - <<'PY'
import base64, os
from pathlib import Path
Path(os.environ['ANDROID_KEYSTORE_PATH']).write_bytes(base64.b64decode(os.environ['ANDROID_KEYSTORE_BASE64'], validate=True))
PY
fi
: "${ANDROID_KEYSTORE_PATH:?Release keystore path or base64 data is required}"
bash android/gradlew assembleRelease
sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
: "${sdk_root:?Android SDK path is required}"
"$sdk_root/build-tools/34.0.0/apksigner" verify --verbose --print-certs android/app/build/outputs/apk/release/app-release.apk
