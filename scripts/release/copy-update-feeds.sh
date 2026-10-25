#!/usr/bin/env bash
# Always overlay the complete feed history when rebuilding the Pages site.
set -euo pipefail
site_dir="${1:-build/site}"
if git ls-remote --exit-code --heads origin sparkle-feeds >/dev/null; then
    git fetch --no-tags origin refs/heads/sparkle-feeds
    mkdir -p "$site_dir"
    git archive FETCH_HEAD updates/macos | tar -xf - -C "$site_dir"
else
    status=$?
    # The data branch does not exist until the first release using Pages.
    if [[ "$status" != 2 ]]; then exit "$status"; fi
fi
