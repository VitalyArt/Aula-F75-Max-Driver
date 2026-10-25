import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/release'))
spec = importlib.util.spec_from_file_location('verify_pages', ROOT / 'scripts/release/verify-pages.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PagesVerificationTests(unittest.TestCase):
    def test_missing_expected_release_fails_before_network(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(FileNotFoundError):
                module.expected_feeds(directory, 'v1.7.0-rc2')
            with self.assertRaises(ValueError):
                module.expected_feeds(directory, '../invalid')

    def test_stale_site_and_404_are_failures(self):
        feeds = {'updates/macos/v1.7.0-rc2.xml': b'signed rc2'}
        self.assertEqual(module.check_publication('https://example.com/app/', feeds, lambda _: b'signed rc2'), [])
        self.assertTrue(module.check_publication('https://example.com/app/', feeds, lambda _: b'signed rc1'))
        def missing(_):
            raise OSError('HTTP 404')
        self.assertIn('404', module.check_publication('https://example.com/app/', feeds, missing)[0])
