import importlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/release'))
identity = importlib.import_module('identity')
package = importlib.import_module('package')
publish = importlib.import_module('publish')


class IdentityTests(unittest.TestCase):
    def test_tags(self):
        for tag in ['1.2.3', 'v1.2.3', 'v1.2.3-alpha.1', 'v1.2.3-beta.2', 'v1.2.3-rc1', 'v1.2.3-rc.1']:
            with self.subTest(tag=tag):
                result = identity.resolve({'RELEASE_TAG': tag, 'GITHUB_RUN_NUMBER': '42'})
                self.assertEqual(result['version'], tag.removeprefix('v'))
                self.assertEqual(result['build'], '42')
                self.assertEqual(result['debian_version'], result['version'].replace('-', '~'))
                self.assertEqual(identity.asset_names(result, 'arm64')[2], result['asset_base'] + '_arm64.deb')
                self.assertEqual(result['channel'], 'alpha' if '-' in tag else 'stable')

    def test_dev_ignores_branch_name(self):
        result = identity.resolve({'GITHUB_REF_NAME': 'feature/test', 'GITHUB_SHA': 'abcdef012345'})
        self.assertEqual(result['version'], '0.1.0+dev.abcdef01')

    def test_invalid(self):
        for tag in ['../bad', 'v1.2', 'v1.2.3-other.1', 'release/v1.2.3']:
            with self.assertRaises(ValueError):
                identity.resolve({'RELEASE_TAG': tag})
        with self.assertRaises(ValueError):
            identity.resolve({'RELEASE_TAG': 'v1.2.3', 'AULA_RELEASE_VERSION': '1.0.0'})


class PackagingTests(unittest.TestCase):
    def test_validation_and_repeat(self):
        with tempfile.TemporaryDirectory() as temp, patch.dict(os.environ, {'RELEASE_DIR': temp, 'RELEASE_TAG': 'v1.2.3'}, clear=True):
            directory = Path(temp)
            with self.assertRaises(ValueError):
                package.prepare()
            for name in ['Aula F75 Max Driver.dmg', 'app-release.apk', 'app.deb']:
                (directory / name).write_text('installer')
            with patch.object(package.subprocess, 'check_output', side_effect=subprocess.CalledProcessError(2, 'dpkg-deb')):
                with self.assertRaises(subprocess.CalledProcessError):
                    package.prepare()
            self.assertFalse(list(directory.glob('*v1.2.3*')))
            with patch.object(package.subprocess, 'check_output', return_value='arm64\n'):
                for _ in range(2):
                    _, targets = package.prepare()
                    self.assertTrue(all(target.read_text() == 'installer' for target in targets))
            self.assertTrue((directory / 'app.deb').exists())

    def test_publication_order_and_retry_with_fake_gh(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            log, state = directory / 'log', directory / 'exists'
            gh = directory / 'gh'
            gh.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$LOG"\nif [ "$2" = view ]; then test -f "$STATE"; exit $?; fi\nif [ "$2" = create ]; then touch "$STATE"; fi\n')
            gh.chmod(0o755)
            feed = directory / 'macos.appcast.xml'
            feed.write_text('signed')
            result = identity.resolve({'RELEASE_TAG': 'v1.2.3-rc1'})
            assets = [directory / name for name in identity.asset_names(result, 'amd64')]
            real_run = subprocess.run
            def run(args, **kwargs):
                if args[0] == 'bash':
                    with log.open('a') as output:
                        output.write('feed\n')
                    if log.read_text().count('feed') == 1:
                        raise subprocess.CalledProcessError(1, args)
                    return subprocess.CompletedProcess(args, 0)
                return real_run(args, **kwargs)
            with patch.dict(os.environ, {'PATH': str(directory) + ':' + os.environ['PATH'], 'LOG': str(log), 'STATE': str(state), 'RELEASE_DIR': temp}), patch.object(publish, 'prepare', return_value=(result, assets)), patch.object(publish.subprocess, 'run', side_effect=run):
                with self.assertRaises(subprocess.CalledProcessError):
                    publish.publish()
                publish.publish()
            lines = log.read_text().splitlines()
            self.assertTrue(lines[1].startswith('release create'))
            self.assertEqual(lines[2], 'feed')
            self.assertTrue(lines[4].startswith('release edit'))
            self.assertTrue(lines[5].startswith('release upload'))
            self.assertEqual(lines[6], 'feed')


class AndroidSigningTests(unittest.TestCase):
    def test_temporary_key_is_removed_when_build_fails(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            fake_bin = directory / 'bin'
            fake_bin.mkdir()
            bash = fake_bin / 'bash'
            bash.write_text('#!/bin/sh\nexit 17\n')
            bash.chmod(0o755)
            env = dict(os.environ, PATH=str(fake_bin) + ':' + os.environ['PATH'],
                       RUNNER_TEMP=temp, ANDROID_KEYSTORE_BASE64='a2V5',
                       ANDROID_KEYSTORE_PASSWORD='test', ANDROID_KEY_ALIAS='test',
                       ANDROID_KEY_PASSWORD='test')
            result = subprocess.run(['/bin/bash', str(ROOT / 'scripts/android/release.sh')],
                                    cwd=ROOT, env=env, capture_output=True)
            self.assertEqual(result.returncode, 17, result.stderr)
            self.assertEqual(list(directory.glob('aula-signing.*')), [])
