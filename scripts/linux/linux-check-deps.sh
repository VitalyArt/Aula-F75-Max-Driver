#!/usr/bin/env bash
set -euo pipefail

if ! command -v pkg-config >/dev/null 2>&1; then
    printf '%s\n' \
        'Missing Linux build dependency: pkg-config' \
        'Install dependencies on Ubuntu with:' \
        '  sudo apt install libgtk-4-dev libhidapi-dev pkg-config' \
        'Install dependencies on Fedora with:' \
        '  sudo dnf install gtk4-devel hidapi-devel pkgconf-pkg-config'
    exit 1
fi

if ! pkg-config --exists gtk4 hidapi-hidraw; then
    printf '%s\n' \
        'Missing Linux build dependencies: gtk4 and/or hidapi-hidraw development files' \
        'Install dependencies on Ubuntu with:' \
        '  sudo apt install libgtk-4-dev libhidapi-dev pkg-config' \
        'Install dependencies on Fedora with:' \
        '  sudo dnf install gtk4-devel hidapi-devel pkgconf-pkg-config'
    exit 1
fi
