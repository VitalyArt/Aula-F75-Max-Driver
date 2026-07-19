#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [ -z "${RELEASE_TAG:-}" ]; then
    printf '%s\n' 'RELEASE_TAG is required'
    exit 1
fi

safe_tag="$(printf '%s' "${RELEASE_TAG}" | tr '/' '-')"
release_version="v${safe_tag#v}"
release_name="${RELEASE_BASE_NAME}-${release_version}"

mv "${RELEASE_DIR}/${SOURCE_MACOS_DMG}" "${RELEASE_DIR}/${release_name}.dmg"
if [ -n "${SOURCE_ANDROID_APK:-}" ]; then
    mv "${RELEASE_DIR}/${SOURCE_ANDROID_APK}" "${RELEASE_DIR}/${release_name}.apk"
fi
if [ -n "${SOURCE_LINUX_DEB:-}" ]; then
    arch="$(dpkg-deb -f "${RELEASE_DIR}/${SOURCE_LINUX_DEB}" Architecture 2>/dev/null || printf '%s' 'amd64')"
    mv "${RELEASE_DIR}/${SOURCE_LINUX_DEB}" "${RELEASE_DIR}/${release_name}_${arch}.deb"
else
    mv "${RELEASE_DIR}/${SOURCE_LINUX_ARTIFACT}" "${RELEASE_DIR}/${release_name}.tar.gz"
fi
