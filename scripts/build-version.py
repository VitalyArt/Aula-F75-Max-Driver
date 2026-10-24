#!/usr/bin/env python3
"""Resolve build identity without modifying source metadata."""
import os
import re
import subprocess

raw = os.environ.get('RELEASE_TAG') or (os.environ.get('GITHUB_REF_NAME', '') if os.environ.get('GITHUB_REF_TYPE') == 'tag' else '')
if raw:
    if not re.fullmatch(r'v?\d+\.\d+\.\d+(?:-(?:alpha|beta|rc)\.?\d+)?', raw):
        raise SystemExit(f'Unsupported release tag: {raw}')
    version = raw.removeprefix('v')
else:
    sha = os.environ.get('GITHUB_SHA') or subprocess.check_output(['git', 'rev-parse', '--short', 'HEAD'], text=True).strip()
    version = '0.1.0+dev.' + sha[:8]
if os.environ.get('GITHUB_ENV'):
    with open(os.environ['GITHUB_ENV'], 'a') as f:
        f.write(f'AULA_RELEASE_VERSION={version}\n')
print(version)
