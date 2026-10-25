"""Exercise durable feed publication and site rebuilds against a local Git remote."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class FeedPublishingTests(unittest.TestCase):
    def test_history_survives_rebuild_and_rerun(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            remote, checkout = root / 'remote.git', root / 'checkout'
            def git(*args):
                return subprocess.check_output(['git', *args], cwd=checkout, stderr=subprocess.DEVNULL, text=True).strip()
            subprocess.run(['git', 'init', '--bare', str(remote)], check=True, capture_output=True)
            checkout.mkdir()
            git('init')
            git('config', 'user.name', 'Test')
            git('config', 'user.email', 'test@example.com')
            git('remote', 'add', 'origin', str(remote))
            (checkout / 'source.txt').write_text('source must not change')
            git('add', '.')
            git('commit', '-m', 'initial')
            source_head = git('rev-parse', 'HEAD')
            def script(name, *args, check=True):
                # Exercise macOS's system Bash 3 as well as Linux's system Bash.
                result = subprocess.run(['/bin/bash', str(ROOT / 'scripts' / 'release' / name), *map(str, args)], cwd=checkout,
                                        capture_output=True, text=True)
                if check and result.returncode:
                    self.fail(f'{name} failed:\n{result.stdout}\n{result.stderr}')
                return result
            site = root / 'site'
            script('copy-update-feeds.sh', site)  # first deployment, no feeds branch yet
            feed = root / 'feed.xml'
            feed.write_text('<signed-feed>rc1</signed-feed>')
            script('publish-update-feed.sh', feed, 'v1.7.0-rc1')
            first_head = git('ls-remote', 'origin', 'sparkle-feeds')
            script('publish-update-feed.sh', feed, 'v1.7.0-rc1')
            self.assertEqual(git('ls-remote', 'origin', 'sparkle-feeds'), first_head)
            feed.write_text('<signed-feed>stable</signed-feed>')
            script('publish-update-feed.sh', feed, 'v1.7.0')
            self.assertNotEqual(script('publish-update-feed.sh', feed, '../invalid', check=False).returncode, 0)
            site.mkdir()
            (site / 'index.html').write_text('website')
            script('copy-update-feeds.sh', site)
            self.assertEqual((site / 'updates/macos/v1.7.0-rc1.xml').read_text(), '<signed-feed>rc1</signed-feed>')
            self.assertEqual((site / 'updates/macos/v1.7.0.xml').read_text(), '<signed-feed>stable</signed-feed>')
            self.assertEqual((site / 'index.html').read_text(), 'website')
            self.assertEqual(git('rev-parse', 'HEAD'), source_head)
            self.assertEqual(git('status', '--porcelain'), '')
            # Rebuilding a clean website must retain both feeds.
            import shutil
            shutil.rmtree(site)
            script('copy-update-feeds.sh', site)
            self.assertEqual(len(list((site / 'updates/macos').glob('*.xml'))), 2)
