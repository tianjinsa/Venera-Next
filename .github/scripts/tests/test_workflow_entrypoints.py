"""Guard test/build isolation and the common build quality barrier."""

import importlib.util
from pathlib import Path
import re
import unittest


WORKFLOWS = Path(__file__).resolve().parents[2] / 'workflows'
SCOPE_PATH = WORKFLOWS.parent / 'scripts/ci_scope.py'
SPEC = importlib.util.spec_from_file_location('workflow_ci_scope', SCOPE_PATH)
SCOPE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SCOPE)


def workflow(name):
    return (WORKFLOWS / name).read_text()


def jobs(text):
    body = text.split('\njobs:\n', 1)[1]
    headings = list(re.finditer(r'^  (\w+):\n', body, re.M))
    result = {}
    for index, match in enumerate(headings):
        end = headings[index + 1].start() if index + 1 < len(headings) else len(body)
        result[match[1]] = body[match.end():end]
    return result


def event_block(text, name):
    body = text.split(f'\n  {name}:\n', 1)[1]
    return re.split(r'\n(?:\S|  \w+:)', body, maxsplit=1)[0]


class WorkflowEntrypointsTests(unittest.TestCase):
    def test_manual_full_tests_have_no_build_inputs_or_build_jobs(self):
        tests = workflow('tests.yml')
        self.assertIn('on:\n  workflow_dispatch:\n\n', tests)
        self.assertEqual(set(jobs(tests)), {'Quality'})
        quality = jobs(tests)['Quality']
        self.assertEqual(
            re.findall(r'^    uses: (.+)$', quality, re.M),
            ['./.github/workflows/analyze.yml'],
        )
        self.assertIn('      platforms: all\n', quality)
        self.assertIn('      skip_tests: false\n', quality)
        self.assertNotRegex(tests, r'(?m)^\s+(?:inputs|if|secrets):')
        self.assertIn('permissions:\n  contents: read\n', tests)

    def test_manual_tests_force_all_checks_even_with_a_docs_only_latest_commit(self):
        paths = SCOPE.changed_paths('workflow_dispatch', {}, 'branch')
        self.assertIsNone(paths)
        self.assertTrue(all(SCOPE.classify(paths, 'all').values()))

    def test_test_run_cancellation_cannot_cancel_a_package_build(self):
        tests = workflow('tests.yml')
        build = workflow('build.yml')
        self.assertIn('  cancel-in-progress: true\n', tests)
        self.assertRegex(tests, r'(?m)^  group: tests-')
        self.assertRegex(build, r'(?m)^  group: build-')

    def test_build_entry_has_no_obsolete_test_only_mode(self):
        build = workflow('build.yml')
        self.assertNotIn('tests_only', build)
        for event in ('workflow_dispatch', 'workflow_call'):
            inputs = event_block(build, event)
            self.assertIn('      skip_tests:\n', inputs)
            for platform in ('android', 'windows', 'macos', 'ios', 'linux_x64', 'linux_arm64'):
                self.assertIn('      build_' + platform + ':\n', inputs)
        self.assertNotIn('quality_checked', event_block(build, 'workflow_dispatch'))

    def test_every_package_job_waits_for_quality_and_accepts_checked_release_callers(self):
        build_jobs = jobs(workflow('build.yml'))
        for name in ('Build_Android', 'Build_Windows', 'Build_Apple', 'Build_Linux'):
            with self.subTest(job=name):
                job = build_jobs[name]
                self.assertIn('    needs: Manual_Quality\n', job)
                condition = re.search(r'^    if: (.+)$', job, re.M)[1]
                self.assertIn('!cancelled()', condition)
                self.assertIn("needs.Manual_Quality.result == 'success'", condition)
                self.assertIn("needs.Manual_Quality.result == 'skipped'", condition)
                self.assertIn('inputs.build_', condition)
        quality = build_jobs['Manual_Quality']
        self.assertIn('!inputs.quality_checked', quality)
        for platform in ('android', 'windows', 'macos', 'ios', 'linux_x64', 'linux_arm64'):
            self.assertIn('inputs.build_' + platform, quality)
        self.assertIn('      skip_tests: ${{ inputs.skip_tests }}\n', quality)
        self.assertIn('      quality_checked: true\n', jobs(workflow('main.yml'))['Build'])

    def test_build_quality_supports_all_selected_platform_families(self):
        quality = jobs(workflow('build.yml'))['Manual_Quality']
        selection = re.search(r'^      platforms: (.+)$', quality, re.M)[1]
        for platform in ('all', 'android', 'apple', 'desktop'):
            self.assertIn("'" + platform + "'", selection)
        for family in ('android', 'desktop'):
            flags = SCOPE.classify(None, family)
            self.assertTrue(flags['flutter'])
            self.assertFalse(flags['apple'] or flags['rhttp_ios'])
        self.assertFalse(SCOPE.classify(None, 'apple')['provider'])
        self.assertFalse(SCOPE.classify(None, 'desktop')['provider'])

    def test_different_package_selections_keep_independent_quality_runs(self):
        quality = jobs(workflow('build.yml'))['Manual_Quality']
        key = re.search(r'^      concurrency_key: (.+)$', quality, re.M)[1]
        for platform in ('android', 'windows', 'macos', 'ios', 'linux_x64', 'linux_arm64'):
            self.assertIn('${{ inputs.build_' + platform + ' }}', key)
        self.assertIn("${{ inputs.concurrency_key || 'default' }}", workflow('analyze.yml'))


if __name__ == '__main__':
    unittest.main()
