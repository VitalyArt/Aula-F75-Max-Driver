import base64
import importlib.util
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

spec = importlib.util.spec_from_file_location('appcast', Path(__file__).resolve().parents[2] / 'scripts/macos-appcast.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class AppcastTests(unittest.TestCase):
    def feed(self, version):
        return ET.fromstring(module.appcast(version, 42, f'App v{version}.dmg', 123,
                                           base64.b64encode(bytes(64)).decode(), 'VitalyArt/Aula-F75-Max-Driver', f'v{version}'))

    def test_stable_feed(self):
        item = self.feed('0.2.0').find('channel/item')
        self.assertEqual(item.find(f'{{{module.SPARKLE}}}version').text, '42')
        self.assertIsNone(item.find(f'{{{module.SPARKLE}}}channel'))
        self.assertIn('App%20v0.2.0.dmg', item.find('enclosure').attrib['url'])
        self.assertEqual(item.find('enclosure').attrib['length'], '123')

    def test_all_preview_versions_use_alpha_channel(self):
        for version in ['0.2.0-alpha.1', '0.2.0-beta.1', '0.2.0-rc1', '0.2.0-rc.1']:
            item = self.feed(version).find('channel/item')
            self.assertEqual(item.find(f'{{{module.SPARKLE}}}channel').text, 'alpha')
            self.assertEqual(item.find(f'{{{module.SPARKLE}}}shortVersionString').text, version)

    def test_invalid_input(self):
        with self.assertRaises(ValueError):
            self.feed('latest')
        with self.assertRaises(ValueError):
            module.appcast('0.2.0', 1, 'app.dmg', 123, 'invalid', 'owner/repo', 'v0.2.0')


if __name__ == '__main__':
    unittest.main()
