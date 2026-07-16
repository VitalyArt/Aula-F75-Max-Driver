#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

linux_root="${BUILD_DIR}/linux"

rm -rf "$linux_root"
mkdir -p "${linux_root}/share/applications"
mkdir -p "${linux_root}/share/icons/hicolor/256x256/apps"
mkdir -p "${linux_root}/share/pixmaps"
mkdir -p "${linux_root}/share/metainfo"
mkdir -p "${linux_root}/share/udev/rules.d"

cp ".build/release/${LINUX_PRODUCT}" "${linux_root}/"
cp "packaging/linux/aula-f75-max-driver.desktop" "${linux_root}/share/applications/${LINUX_DESKTOP_ID}.desktop"
cp "docs/assets/app-icon.png" "${linux_root}/share/icons/hicolor/256x256/apps/${LINUX_DESKTOP_ID}.png"
cp "docs/assets/app-icon.png" "${linux_root}/share/pixmaps/${LINUX_DESKTOP_ID}.png"
cp "packaging/linux/aula-f75-max-driver.metainfo.xml" "${linux_root}/share/metainfo/${LINUX_APPSTREAM_ID}.metainfo.xml"
cp "packaging/linux/60-aula-f75-max.rules" "${linux_root}/share/udev/rules.d/"
tar -C "${BUILD_DIR}" -czf "${LINUX_ARTIFACT}" linux
