#!/usr/bin/env bash
set -euo pipefail

# Existing terminal sessions may not have loaded Swiftly's PATH yet.
if ! command -v swift >/dev/null 2>&1; then
    swiftly_env="${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh"
    if [[ -f "$swiftly_env" ]]; then
        source "$swiftly_env"
    fi
fi

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

swift run -c "${CONFIGURATION}" "${LINUX_PRODUCT}"
