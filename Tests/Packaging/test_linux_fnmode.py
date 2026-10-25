from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class LinuxFnmodeTests(unittest.TestCase):
    def test_package_configuration(self):
        config = ROOT / 'packaging/linux/aula-f75-max.conf'
        self.assertIn('options hid_apple fnmode=2', config.read_text().splitlines())
        self.assertEqual((ROOT / 'packaging/linux/deb-conffiles').read_text(),
                         '/etc/modprobe.d/aula-f75-max.conf\n')
        builder = (ROOT / 'scripts/linux/linux-deb.sh').read_text()
        self.assertIn('install -m 0644 "packaging/linux/aula-f75-max.conf" "${root}/etc/modprobe.d/"', builder)
        self.assertIn('install -m 0644 "packaging/linux/deb-conffiles" "${root}/DEBIAN/conffiles"', builder)

    def run_hook(self, hook, action, module='present', initramfs='success', repeat=1):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            parameter = directory / 'fnmode'
            if module == 'present':
                parameter.write_text('1\n')
            elif module == 'unwritable':
                # A directory reliably rejects writes even when tests run as root.
                parameter.mkdir()
            log = directory / 'initramfs.log'
            if initramfs != 'absent':
                command = directory / 'update-initramfs'
                command.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$TEST_LOG"\nexit ' +
                                   ('1' if initramfs == 'failure' else '0') + '\n')
                command.chmod(0o755)
            source = (ROOT / 'packaging/linux' / hook).read_text()
            # Rewrite only the test copy; never touch the host's sysfs or caches.
            source = source.replace('/sys/module/hid_apple/parameters/fnmode', str(parameter))
            for utility in ('udevadm', 'glib-compile-schemas', 'update-desktop-database', 'gtk-update-icon-cache'):
                source = source.replace(utility, 'unavailable-test-' + utility)
            env = dict(os.environ, PATH=temp, TEST_LOG=str(log))
            for _ in range(repeat):
                result = subprocess.run(['/bin/sh', '-s', '--', action], input=source,
                                        text=True, capture_output=True, env=env)
                self.assertEqual(result.returncode, 0, result.stderr)
            value = parameter.read_text() if parameter.is_file() else None
            return result, value, log.read_text() if log.exists() else ''

    def test_configure_and_repeat(self):
        result, value, log = self.run_hook('deb-postinst', 'configure', repeat=2)
        self.assertEqual(value, '2\n')
        self.assertEqual(log, '-u\n-u\n')
        self.assertNotIn('Warning:', result.stderr)

    def test_missing_module(self):
        result, value, log = self.run_hook('deb-postinst', 'configure', module='absent')
        self.assertIsNone(value)
        self.assertEqual(log, '-u\n')
        self.assertNotIn('Warning:', result.stderr)

    def test_write_failure_is_nonfatal(self):
        result, _, log = self.run_hook('deb-postinst', 'configure', module='unwritable')
        self.assertIn('Warning: could not set hid_apple', result.stderr)
        self.assertEqual(log, '-u\n')

    def test_missing_initramfs(self):
        result, value, log = self.run_hook('deb-postinst', 'configure', initramfs='absent')
        self.assertEqual(value, '2\n')
        self.assertEqual(log, '')
        self.assertNotIn('Warning:', result.stderr)

    def test_initramfs_failure_is_nonfatal(self):
        for hook, action in [('deb-postinst', 'configure'), ('deb-postrm', 'purge')]:
            with self.subTest(hook=hook):
                result, _, _ = self.run_hook(hook, action, initramfs='failure')
                self.assertIn('Warning: could not update initramfs', result.stderr)

    def test_other_actions_do_not_apply_fix(self):
        for hook, action in [('deb-postinst', 'abort-upgrade'), ('deb-postrm', 'remove')]:
            with self.subTest(hook=hook):
                _, value, log = self.run_hook(hook, action)
                self.assertEqual(value, '1\n')
                self.assertEqual(log, '')

    def test_purge_keeps_runtime_value(self):
        _, value, log = self.run_hook('deb-postrm', 'purge')
        self.assertEqual(value, '1\n')
        self.assertEqual(log, '-u\n')
