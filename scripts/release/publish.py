#!/usr/bin/env python3
"""Publish installers before exposing their signed update metadata."""
import os
from pathlib import Path
import subprocess
from package import prepare


def publish():
    identity, assets = prepare()
    directory = Path(os.environ.get('RELEASE_DIR', 'release'))
    feed = directory / 'macos.appcast.xml'
    if not feed.is_file():
        raise ValueError(f'Missing signed appcast: {feed}')
    tag = identity['tag']
    exists = subprocess.run(['gh', 'release', 'view', tag], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    if exists:
        if identity['channel'] == 'alpha':
            subprocess.run(['gh', 'release', 'edit', tag, '--prerelease', '--latest=false'], check=True)
        subprocess.run(['gh', 'release', 'upload', tag, *map(str, assets), '--clobber'], check=True)
    else:
        flags = ['--prerelease', '--latest=false'] if identity['channel'] == 'alpha' else []
        subprocess.run(['gh', 'release', 'create', tag, *map(str, assets), *flags, '--title', tag, '--generate-notes'], check=True)
    subprocess.run(['bash', str(Path(__file__).with_name('publish-update-feed.sh')), str(feed), tag], check=True)


if __name__ == '__main__':
    publish()
