import contextlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import build_android
import ci_scope
import prepare_android_space as space
import prepare_rust_toolchain as rust


class ScopeTests(unittest.TestCase):
    def test_docs_skip_heavy_work_but_unknown_paths_and_dependencies_keep_it(self):
        self.assertFalse(any(ci_scope.classify(['README.md', 'doc/user/guide.zh.md']).values()))
        for path in ('new-build-input', 'pubspec.lock', '.github/workflows/build.yml',
                     '.github/actions/rust-cache/action.yml', '.github/scripts/ci_scope.py'):
            with self.subTest(path=path):
                self.assertTrue(all(ci_scope.classify([path]).values()))

    def test_runtime_changes_keep_flutter_and_platform_contracts(self):
        flags = ci_scope.classify(['lib/features/agent/agent_page.dart'])
        for name in ('flutter', 'analyze', 'android', 'windows'):
            self.assertTrue(flags[name])
        for name in ('apple', 'rhttp_ios', 'provider', 'macos', 'ios'):
            self.assertFalse(flags[name])
        self.assertTrue(ci_scope.classify(['lib/features/local_comics/local.dart'])['provider'])
        self.assertTrue(ci_scope.classify(['packages/venera_saf/src/saf.cpp'])['provider'])
        self.assertTrue(ci_scope.classify(['packages/rhttp/rust/src/api.rs'])['rhttp_ios'])

    def test_selected_platforms_remove_unrelated_checks_even_for_full_manual_runs(self):
        flags = ci_scope.classify(None, 'android')
        self.assertTrue(flags['flutter'])
        self.assertTrue(flags['provider'])
        self.assertFalse(flags['apple'])
        self.assertFalse(flags['rhttp_ios'])
        self.assertFalse(ci_scope.classify(None, 'apple')['provider'])
        with self.assertRaises(ValueError):
            ci_scope.classify(None, 'typo')

    def test_platform_only_changes_select_only_the_required_smoke_runners(self):
        flags = ci_scope.classify(['packages/example/windows/plugin.cpp'])
        self.assertTrue(flags['windows'])
        self.assertFalse(flags['android'])
        self.assertEqual(json.loads(ci_scope.outputs(flags)['desktop_matrix']), {'include': []})
        flags = ci_scope.classify(['linux/CMakeLists.txt'])
        self.assertEqual([item['target'] for item in json.loads(ci_scope.outputs(flags)['desktop_matrix'])['include']], ['linux'])

    def test_manual_tag_invalid_and_missing_diff_inputs_fall_back_to_full_checks(self):
        for event, payload, ref_type in (
            ('workflow_dispatch', {}, 'branch'), ('push', {}, 'tag'),
            ('push', {'before': '0' * 40, 'after': 'a' * 40}, 'branch'),
            ('pull_request', {}, 'branch'),
        ):
            self.assertIsNone(ci_scope.changed_paths(event, payload, ref_type))
        git = Mock(side_effect=subprocess.CalledProcessError(128, 'git'))
        self.assertIsNone(ci_scope.changed_paths('push', {'before': 'a' * 40, 'after': 'b' * 40}, 'branch', git))

    def test_real_git_diff_covers_all_commits_and_renames_into_code(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            def git(*args):
                return subprocess.check_output(['git', '-C', str(root), *args], stderr=subprocess.PIPE)
            def commit(message):
                git('add', '.')
                git('-c', 'user.name=fixture', '-c', 'user.email=fixture@example.test', 'commit', '-m', message)
                return git('rev-parse', 'HEAD').decode().strip()
            git('init')
            (root / 'README.md').write_text('docs')
            base = commit('baseline')
            (root / 'lib').mkdir()
            (root / 'README.md').rename(root / 'lib/new.dart')
            commit('rename into runtime')
            (root / 'doc.md').write_text('later docs')
            head = commit('docs after runtime')
            paths = ci_scope.changed_paths('push', {'before': base, 'after': head}, 'branch', git)
            self.assertIn('README.md', paths)
            self.assertIn('lib/new.dart', paths)
            self.assertTrue(ci_scope.classify(paths)['flutter'])
            event = {'pull_request': {'base': {'sha': base}, 'head': {'sha': head}}}
            self.assertEqual(ci_scope.changed_paths('pull_request', event, 'branch', git), paths)


class AndroidBuildTests(unittest.TestCase):
    def test_android_selection_always_builds_the_complete_release_set(self):
        for environment in ({}, {'GITHUB_REF_TYPE': 'tag'},
                            {'ANDROID_FLAVORS': 'mobile', 'ANDROID_ARCHITECTURE': 'arm64'}):
            plan = build_android.build_plan(environment)
            self.assertEqual(plan['flavors'], ['mobile', 'tv'])
            self.assertEqual(plan['architecture'], 'all')
            self.assertEqual(plan['native_abis'], list(build_android.TARGETS))
            self.assertEqual(len(plan['apks']), 4)

    def test_flavors_share_workspace_but_preserve_verified_outputs_before_next_build(self):
        with tempfile.TemporaryDirectory() as temporary, contextlib.chdir(temporary):
            Path('pubspec.yaml').write_text('version: 1.18.3+249\n')
            environment = {'GITHUB_SHA': 'a' * 40, 'GITHUB_REF': 'refs/heads/development'}
            plan = build_android.build_plan(environment)
            order = []
            def compile(command, *, env, check):
                flavor = command[command.index('--flavor') + 1]
                order.append(('compile', flavor))
                self.assertEqual(env['ANDROID_BUILD_ABIS'], 'armeabi-v7a,arm64-v8a,x86_64')
                self.assertIn('--no-pub', command)
                self.assertNotIn('clean', command)
                self.assertEqual(command[command.index('--target-platform') + 1], 'android-arm,android-arm64,android-x64')
                self.assertNotIn('--split-per-abi', command)
                if flavor == 'tv':
                    self.assertIn('--dart-define=TV_REVISION=' + 'a' * 40, command)
                    # Flutter may overwrite its shared output directory.
                    shutil.rmtree('build/app')
                Path('build/app').mkdir(parents=True)
                Path(f'build/app/{flavor}.apk').write_bytes(flavor.encode())
            def verify(metadata, sdk, *, abis, expected_signer_sha256):
                flavor = metadata['flavor']
                order.append(('verify', flavor))
                self.assertEqual(abis, ['armeabi-v7a', 'arm64-v8a', 'x86_64', 'universal'])
                self.assertEqual(expected_signer_sha256, build_android.android.SIGNER_SHA256)
                manifest = Path(f'build/android-{flavor}-manifest.json')
                manifest.write_text(json.dumps(metadata))
                return {'apk_arm64_v8a': f'build/app/{flavor}.apk', 'manifest': str(manifest)}
            with patch.object(build_android.subprocess, 'run', side_effect=compile), \
                    patch.object(build_android.android, 'verify_apks', side_effect=verify):
                build_android.build(plan, environment)
            self.assertEqual(order, [('compile', 'mobile'), ('verify', 'mobile'), ('compile', 'tv'), ('verify', 'tv')])
            artifacts = Path('build/android-artifacts')
            self.assertEqual((artifacts / 'mobile.apk').read_bytes(), b'mobile')
            self.assertEqual((artifacts / 'tv.apk').read_bytes(), b'tv')
            self.assertEqual(len(list(artifacts.iterdir())), 4)

    def test_failed_first_flavor_stops_before_second_and_does_not_reuse_old_artifacts(self):
        with tempfile.TemporaryDirectory() as temporary, contextlib.chdir(temporary):
            Path('pubspec.yaml').write_text('version: 1.18.3+249\n')
            Path('build/android-artifacts').mkdir(parents=True)
            Path('build/android-artifacts/old.apk').write_bytes(b'old')
            with patch.object(build_android.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, 'flutter')) as command:
                with self.assertRaises(subprocess.CalledProcessError):
                    build_android.build(build_android.build_plan({}), {'GITHUB_SHA': 'a' * 40})
                self.assertEqual(command.call_count, 1)
            self.assertEqual(list(Path('build/android-artifacts').iterdir()), [])


class PreparationTests(unittest.TestCase):
    def test_installed_rust_toolchain_and_targets_do_not_trigger_reinstallation(self):
        with patch.object(rust.subprocess, 'run', return_value=Mock(returncode=0)) as run, \
                patch.object(rust.subprocess, 'check_output', return_value='aarch64-linux-android\n'):
            rust.prepare_toolchain('1.92.0', ['aarch64-linux-android'])
            self.assertEqual(run.call_count, 2)
            self.assertFalse(any('install' in call.args[0] or 'uninstall' in call.args[0] for call in run.call_args_list))

    def test_missing_rust_targets_are_added_once_without_removing_the_toolchain(self):
        with patch.object(rust.subprocess, 'run', return_value=Mock(returncode=0)) as run, \
                patch.object(rust.subprocess, 'check_output', return_value=''):
            rust.prepare_toolchain('1.92.0', ['aarch64-linux-android'] * 2)
            self.assertIn(unittest.mock.call(['rustup', 'target', 'add', '--toolchain', '1.92.0', 'aarch64-linux-android'], check=True), run.call_args_list)

    def test_missing_rust_toolchain_is_installed_with_minimal_profile(self):
        with patch.object(rust.subprocess, 'run', side_effect=[Mock(returncode=1), Mock(returncode=0), Mock(returncode=0)]) as run, \
                patch.object(rust.subprocess, 'check_output', return_value=''):
            rust.prepare_toolchain('1.92.0', [])
            self.assertIn(unittest.mock.call(['rustup', 'toolchain', 'install', '1.92.0', '--profile', 'minimal', '--component', 'cargo'], check=True), run.call_args_list)

    def test_sufficient_disk_space_never_deletes_tools(self):
        with patch.object(space.shutil, 'disk_usage', return_value=Mock(free=30 * space.GIB)), \
                patch.object(space.subprocess, 'run') as run, contextlib.redirect_stdout(io.StringIO()):
            space.prepare_space()
            run.assert_not_called()

    def test_hosted_cleanup_stops_as_soon_as_space_is_sufficient(self):
        with patch.dict(os.environ, {'RUNNER_ENVIRONMENT': 'github-hosted'}), \
                patch.object(space.shutil, 'disk_usage', side_effect=[Mock(free=10 * space.GIB), Mock(free=25 * space.GIB)]), \
                patch.object(space.Path, 'exists', return_value=True), patch.object(space.subprocess, 'run') as run, \
                contextlib.redirect_stdout(io.StringIO()):
            space.prepare_space()
            run.assert_called_once_with(['sudo', 'rm', '-rf', '--', '/usr/share/dotnet'], check=True)

    def test_insufficient_self_hosted_space_fails_without_deleting_anything(self):
        with patch.dict(os.environ, {'RUNNER_ENVIRONMENT': 'self-hosted'}), \
                patch.object(space.shutil, 'disk_usage', return_value=Mock(free=space.GIB)), \
                patch.object(space.subprocess, 'run') as run, contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(RuntimeError):
                space.prepare_space()
            run.assert_not_called()
