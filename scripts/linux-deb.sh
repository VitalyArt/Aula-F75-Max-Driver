#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v dpkg-deb >/dev/null 2>&1; then
    printf '%s\n' 'Missing Linux packaging dependency: dpkg-deb'
    exit 1
fi

if ! python3 -c 'from PIL import Image' >/dev/null 2>&1; then
    printf '%s\n' \
        'Missing Linux packaging dependency: python3-pil' \
        'Install dependencies on Ubuntu with:' \
        '  sudo apt install python3-pil'
    exit 1
fi

arch="$(dpkg --print-architecture)"
version="${RELEASE_TAG:-}"
if [ -z "$version" ]; then version="1.0.0"; fi
version="${version#v}"
version="$(printf '%s' "$version" | tr '/' '-')"

deb_path="${LINUX_DEB:-}"
if [ -z "$deb_path" ]; then
    deb_path="${BUILD_DIR}/${LINUX_PACKAGE_NAME}_${version}_${arch}.deb"
fi

root="${BUILD_DIR}/deb-root"
install_dir="${root}${LINUX_INSTALL_PREFIX}"
binary=".build/release/${LINUX_PRODUCT}"

rm -rf "$root"
mkdir -p \
    "${root}/DEBIAN" \
    "${install_dir}/lib" \
    "${root}/usr/bin" \
    "${root}/usr/share/doc/${LINUX_PACKAGE_NAME}" \
    "${root}/usr/share/applications" \
    "${root}/usr/share/icons/hicolor/256x256/apps" \
    "${root}/usr/share/pixmaps" \
    "${root}/usr/share/metainfo" \
    "${root}/etc/udev/rules.d"

install -m 0755 "$binary" "${install_dir}/${LINUX_PRODUCT}"
ldd "$binary" | awk '/libswift.*=>/ { print $3 }' | while read -r lib; do
    if [ -n "$lib" ] && [ -f "$lib" ]; then install -m 0644 "$lib" "${install_dir}/lib/"; fi
done

printf '%s\n' \
    '#!/bin/sh' \
    "export LD_LIBRARY_PATH=\"${LINUX_INSTALL_PREFIX}/lib:\${LD_LIBRARY_PATH:-}\"" \
    "exec \"${LINUX_INSTALL_PREFIX}/${LINUX_PRODUCT}\" \"\$@\"" \
    > "${root}/usr/bin/${LINUX_PRODUCT}"
chmod 0755 "${root}/usr/bin/${LINUX_PRODUCT}"

install -m 0644 "packaging/linux/aula-f75-max-driver.desktop" "${root}/usr/share/applications/${LINUX_DESKTOP_ID}.desktop"
install -m 0644 "docs/assets/app-icon.png" "${root}/usr/share/icons/hicolor/256x256/apps/${LINUX_DESKTOP_ID}.png"
install -m 0644 "docs/assets/app-icon.png" "${root}/usr/share/pixmaps/${LINUX_DESKTOP_ID}.png"
install -m 0644 "packaging/linux/aula-f75-max-driver.metainfo.xml" "${root}/usr/share/metainfo/${LINUX_APPSTREAM_ID}.metainfo.xml"
install -m 0644 "packaging/linux/60-aula-f75-max.rules" "${root}/etc/udev/rules.d/"
install -m 0644 "LICENSE" "${root}/usr/share/doc/${LINUX_PACKAGE_NAME}/copyright"

installed_size="$(du -sk "$root" | awk '{ print $1 }')"
build_date="$(date -u +%F)"
sed \
    -e "s/@PACKAGE_NAME@/${LINUX_PACKAGE_NAME}/g" \
    -e "s/@VERSION@/${version}/g" \
    -e "s/@ARCH@/${arch}/g" \
    -e "s/@INSTALLED_SIZE@/${installed_size}/g" \
    -e "s/@BUILD_DATE@/${build_date}/g" \
    "packaging/linux/deb-control.in" > "${root}/DEBIAN/control"
scripts/embed-deb-icon.py "${root}/DEBIAN/control" "docs/assets/app-icon.png"

install -m 0755 "packaging/linux/deb-postinst" "${root}/DEBIAN/postinst"
install -m 0755 "packaging/linux/deb-postrm" "${root}/DEBIAN/postrm"
mkdir -p "$(dirname "$deb_path")"
dpkg-deb --build --root-owner-group "$root" "$deb_path"
printf '%s\n' "Built $deb_path"
