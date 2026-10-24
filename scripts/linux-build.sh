#!/usr/bin/env bash
set -euo pipefail

# Existing terminal sessions may not have loaded Swiftly's PATH yet.
if ! command -v swift >/dev/null 2>&1; then
    swiftly_env="${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh"
    if [[ -f "$swiftly_env" ]]; then
        source "$swiftly_env"
    fi
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

swift build -c "${CONFIGURATION}" --product "${LINUX_PRODUCT}"

printf '%s\n' "${AULA_RELEASE_VERSION:-$(python3 scripts/build-version.py)}" > .build/release/version.txt
