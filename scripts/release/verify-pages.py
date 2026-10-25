#!/usr/bin/env python3
"""Verify the public signed bytes, rather than trusting a successful Pages deployment."""
import argparse
from pathlib import Path
import time
from urllib.parse import quote
from urllib.request import Request, urlopen

from identity import release_version


def expected_feeds(site, tag=''):
    directory = Path(site) / 'updates' / 'macos'
    if tag:
        release_version(tag)
        paths = [directory / f'{tag}.xml']
    else:
        paths = sorted(directory.glob('*.xml'))
    return {f'updates/macos/{path.name}': path.read_bytes() for path in paths}


def fetch(url):
    request = Request(url, headers={'Cache-Control': 'no-cache', 'User-Agent': 'Aula-Pages-Verification'})
    with urlopen(request, timeout=15) as response:
        return response.read()


def check_publication(base_url, feeds, download=fetch):
    failures = []
    for relative, expected in feeds.items():
        url = base_url.rstrip('/') + '/' + quote(relative, safe='/')
        try:
            if download(url) != expected:
                failures.append(f'{relative}: public contents differ from the signed appcast')
        except Exception as error:
            failures.append(f'{relative}: {error}')
    return failures


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('site', type=Path)
    parser.add_argument('base_url')
    parser.add_argument('--tag', default='')
    args = parser.parse_args()
    feeds = expected_feeds(args.site, args.tag)
    deadline = time.monotonic() + 180
    while True:
        failures = check_publication(args.base_url, feeds)
        if not failures:
            print(f'Verified {len(feeds)} public signed appcast(s).')
            return
        if time.monotonic() >= deadline:
            raise SystemExit('\n'.join(failures))
        print('\n'.join(failures), flush=True)
        time.sleep(5)


if __name__ == '__main__':
    main()
