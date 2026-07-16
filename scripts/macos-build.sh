#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

CLANG_MODULE_CACHE_PATH=/private/tmp/clang-cache swift build -c "${CONFIGURATION}" --arch arm64
