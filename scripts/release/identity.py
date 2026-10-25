"""Shared build and release identity; no source files are modified."""
import argparse
import json
import os
import re
import subprocess

TAG_PATTERN = r'v?[0-9]+\.[0-9]+\.[0-9]+(?:-(?:alpha|beta|rc)\.?[0-9]+)?'
BASE_NAME = 'AulaF75MaxDriver'


def release_version(tag):
    if not re.fullmatch(TAG_PATTERN, tag):
        raise ValueError(f'Unsupported release tag: {tag}')
    return tag.removeprefix('v')


def resolve(environ=None):
    env = os.environ if environ is None else environ
    tag = env.get('RELEASE_TAG') or (env.get('GITHUB_REF_NAME', '') if env.get('GITHUB_REF_TYPE') == 'tag' else '')
    if tag:
        version = release_version(tag)
        if env.get('AULA_RELEASE_VERSION') and env['AULA_RELEASE_VERSION'] != version:
            raise ValueError('AULA_RELEASE_VERSION does not match release tag')
    else:
        sha = env.get('GITHUB_SHA') or subprocess.check_output(['git', 'rev-parse', '--short=8', 'HEAD'], text=True).strip()
        version = '0.1.0+dev.' + sha[:8]
    build = env.get('GITHUB_RUN_NUMBER') or '1'
    if not build.isdigit() or int(build) <= 0:
        raise ValueError('Build number must be a positive integer')
    return dict(version=version, debian_version=version.replace('-', '~', 1),
                channel='alpha' if '-' in version else 'stable', build=build,
                tag=tag, asset_base=f'{BASE_NAME}-v{version}')


def asset_names(identity, architecture):
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', architecture):
        raise ValueError('Invalid Debian architecture')
    base = identity['asset_base']
    return [base + '.dmg', base + '.apk', base + '_' + architecture + '.deb']


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--field')
    parser.add_argument('--github-env', action='store_true')
    args = parser.parse_args()
    try:
        identity = resolve()
    except ValueError as error:
        parser.error(str(error))
    if args.github_env and os.environ.get('GITHUB_ENV'):
        with open(os.environ['GITHUB_ENV'], 'a') as output:
            output.write('AULA_RELEASE_VERSION=' + identity['version'] + '\n')
    print(identity[args.field] if args.field else json.dumps(identity))


if __name__ == '__main__':
    main()
