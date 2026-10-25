#!/usr/bin/env python3
"""Validate and copy a complete installer set, preserving original artifacts."""
import os
from pathlib import Path
import shutil
import subprocess
from identity import resolve, asset_names


def prepare():
    identity = resolve()
    if not identity['tag']:
        raise ValueError('RELEASE_TAG is required')
    directory = Path(os.environ.get('RELEASE_DIR', 'release'))
    sources = [directory / os.environ.get(key, default) for key, default in [
        ('SOURCE_MACOS_DMG', 'Aula F75 Max Driver.dmg'),
        ('SOURCE_ANDROID_APK', 'app-release.apk'),
        ('SOURCE_LINUX_DEB', 'app.deb')]]
    for source in sources:
        if not source.is_file():
            raise ValueError(f'Missing installer: {source}')
    architecture = subprocess.check_output(['dpkg-deb', '-f', str(sources[2]), 'Architecture'], text=True).strip()
    names = asset_names(identity, architecture)
    targets = [directory / name for name in names]
    for source, target in zip(sources, targets):
        if source.resolve() != target.resolve():
            shutil.copy2(source, target)
    return identity, targets


if __name__ == '__main__':
    prepare()
