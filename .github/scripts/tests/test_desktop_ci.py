import importlib.util
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch
import zipfile

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
import ci_scope
import prepare_apple_build as apple
import prepare_linux_build as linux


def step_script(name):
    text = (SCRIPTS.parent / 'workflows/build.yml').read_text()
    match = re.search(rf'^      - name: {re.escape(name)}\n        run: \|\n((?:          [^\n]*\n)+)', text, re.M)
    if match is None:
        raise AssertionError(name)
    return '\n'.join(line[10:] for line in match[1].splitlines())


class DesktopPreparationTests(unittest.TestCase):
    def test_apple_targets_follow_selected_products(self):
        self.assertEqual(apple.selected_targets(False, True), ['aarch64-apple-ios'])
        self.assertEqual(apple.selected_targets(True, False), ['aarch64-apple-darwin', 'x86_64-apple-darwin'])
        self.assertEqual(apple.selected_targets(True, True), ['aarch64-apple-darwin', 'x86_64-apple-darwin', 'aarch64-apple-ios'])
        with self.assertRaises(ValueError):
            apple.selected_targets(False, False)

    def test_complete_linux_runner_does_not_contact_apt(self):
        result = Mock(returncode=0, stdout='ccache:amd64\tinstall ok installed\ncmake\tinstall ok installed\n')
        with patch.object(linux.subprocess, 'run', return_value=result) as run, patch.object(linux.shutil, 'which', return_value=None):
            linux.prepare(['ccache', 'cmake'])
        self.assertEqual(run.call_count, 1)

    def test_linux_installs_only_missing_packages_after_one_update(self):
        result = Mock(returncode=1, stdout='cmake\tinstall ok installed\n')
        with patch.object(linux.subprocess, 'run', return_value=result) as run, patch.object(linux.shutil, 'which', return_value=None):
            linux.prepare(['ccache', 'cmake'])
        commands = [call.args[0] for call in run.call_args_list]
        self.assertEqual(sum('update' in command for command in commands), 1)
        self.assertEqual(sum('install' in command for command in commands), 1)
        self.assertIn('ccache', commands[-1])
        self.assertNotIn('cmake', commands[-1])

    def test_tools_installed_outside_apt_are_reused(self):
        result = Mock(returncode=1, stdout='')
        with patch.object(linux.subprocess, 'run', return_value=result) as run, \
                patch.object(linux.shutil, 'which', return_value='/tool/cache/executable'):
            linux.prepare(['ccache', 'cmake', 'clang', 'ninja-build', 'pkg-config'])
        self.assertEqual(run.call_count, 1)

    def test_linux_package_list_cannot_inject_apt_options(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'packages.txt'
            path.write_text('cmake\n--allow-unauthenticated\n')
            with self.assertRaises(ValueError):
                linux.packages(path)

    def test_maintenance_changes_select_the_platform_they_control(self):
        flags = ci_scope.classify(['.github/scripts/prepare_apple_build.py'])
        self.assertTrue(flags['macos'] and flags['ios'])
        self.assertFalse(flags['android'] or flags['linux'])
        for filename in ('prepare_linux_build.py', 'arch-builder.Dockerfile', 'test_appimage.sh'):
            flags = ci_scope.classify(['.github/scripts/' + filename])
            self.assertTrue(flags['linux'])
            self.assertFalse(flags['windows'] or flags['macos'] or flags['android'])


@unittest.skipUnless(os.name == 'posix' and shutil.which('bash'), 'Requires Bash')
class ApplePackagingTests(unittest.TestCase):
    def test_dmg_clone_fallback_does_not_leave_a_partial_or_nested_app(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            app = root / 'build/macos/Build/Products/Release/VeneraNext.app'
            (app / 'Contents').mkdir(parents=True)
            (app / 'Contents/app').write_bytes(b'app')
            tools = root / 'bin'
            tools.mkdir()
            cp = tools / 'cp'
            cp.write_text('#!/bin/sh\nif [ "$1" = "-cR" ]; then mkdir -p dist/dmg_contents/VeneraNext.app; touch dist/dmg_contents/VeneraNext.app/partial; exit 1; fi\nexec /bin/cp "$@"\n')
            cp.chmod(0o755)
            hdiutil = tools / 'hdiutil'
            hdiutil.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > hdiutil-args\ntouch dist/VeneraNext.dmg\n')
            hdiutil.chmod(0o755)
            subprocess.run(['bash', '-e', '-c', step_script('创建 DMG')], cwd=root,
                           env=dict(os.environ, PATH=str(tools) + os.pathsep + os.environ['PATH']), check=True)
            staged = root / 'dist/dmg_contents/VeneraNext.app'
            self.assertEqual((staged / 'Contents/app').read_bytes(), b'app')
            self.assertFalse((staged / 'partial').exists())
            self.assertFalse((staged / 'VeneraNext.app').exists())
            self.assertIn('zlib-level=1', (root / 'hdiutil-args').read_text())

    @unittest.skipUnless(shutil.which('zip'), 'Requires zip')
    def test_fast_ipa_keeps_the_payload_bundle_and_assets(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            app = root / 'build/ios/iphoneos/Runner.app'
            app.mkdir(parents=True)
            (app / 'Info.plist').write_bytes(b'plist')
            (app / 'asset').write_bytes(b'asset')
            subprocess.run(['bash', '-e', '-c', step_script('创建 IPA')], cwd=root, check=True, capture_output=True)
            with zipfile.ZipFile(root / 'build/ios/iphoneos/VeneraNext-ios.ipa') as archive:
                self.assertEqual(archive.read('Payload/Runner.app/Info.plist'), b'plist')
                self.assertEqual(archive.read('Payload/Runner.app/asset'), b'asset')
