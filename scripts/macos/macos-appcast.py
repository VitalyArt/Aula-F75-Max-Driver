#!/usr/bin/env python3
"""Generate a signed, release-local Sparkle feed. Private key is passed on stdin to sign_update."""
import argparse
import base64
from datetime import datetime, timezone
import os
from pathlib import Path
import sys
import subprocess
from urllib.parse import quote
import xml.etree.ElementTree as ET

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "release"))
from identity import resolve, release_version

SPARKLE = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', SPARKLE)


def appcast(version, build, archive_name, archive_size, signature, repository, tag):
    release_version(version)
    if len(base64.b64decode(signature, validate=True)) != 64:
        raise ValueError('Invalid EdDSA signature')
    if not str(build).isdigit() or int(build) <= 0:
        raise ValueError('Invalid build number')
    root = ET.Element('rss', version='2.0')
    channel = ET.SubElement(root, 'channel')
    ET.SubElement(channel, 'title').text = 'Aula F75 Max Driver'
    item = ET.SubElement(channel, 'item')
    ET.SubElement(item, 'title').text = version
    ET.SubElement(item, 'link').text = f'https://github.com/{repository}/releases/tag/{quote(tag, safe="")}'
    ET.SubElement(item, 'pubDate').text = datetime.now(timezone.utc).strftime('%a, %d %b %Y %H:%M:%S +0000')
    for key, value in [('version', str(build)), ('shortVersionString', version), ('minimumSystemVersion', '14.0.0'), ('hardwareRequirements', 'arm64')]:
        ET.SubElement(item, f'{{{SPARKLE}}}{key}').text = value
    if '-' in version:
        ET.SubElement(item, f'{{{SPARKLE}}}channel').text = 'alpha'
    ET.SubElement(item, 'enclosure', {
        'url': f'https://github.com/{repository}/releases/download/{quote(tag, safe="")}/{quote(archive_name, safe="")}',
        f'{{{SPARKLE}}}edSignature': signature, 'length': str(archive_size), 'type': 'application/octet-stream'})
    ET.indent(root)
    return ET.tostring(root, encoding='utf-8', xml_declaration=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('archive', type=Path)
    parser.add_argument('--sign-tool', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    identity = resolve()
    version = identity['version']
    tag = identity['tag']
    if not tag:
        parser.error('Release tag is required')
    key = os.environ['SPARKLE_PRIVATE_KEY']
    signature = subprocess.check_output([str(args.sign_tool), '--ed-key-file', '-', '-p', str(args.archive)], input=key, text=True).strip()
    args.output.write_bytes(appcast(version, identity['build'], identity['asset_base'] + '.dmg', args.archive.stat().st_size,
                                   signature, os.environ.get('GITHUB_REPOSITORY', 'VitalyArt/Aula-F75-Max-Driver'), tag))
    # Verify the feed before Sparkle shows its contents, as well as verifying the DMG.
    subprocess.run([str(args.sign_tool), '--ed-key-file', '-', str(args.output)], input=key, text=True, check=True, stdout=subprocess.DEVNULL)


if __name__ == '__main__':
    main()
