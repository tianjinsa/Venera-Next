"""Exercise resource limits and command reporting without running a build."""

import contextlib
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "ci_resources.py"
SPEC = importlib.util.spec_from_file_location("ci_resources", SCRIPT)
CI = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CI)
GIB = CI.GIB


class ResourceBudgetTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)

    def write(self, name, value):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value, encoding="utf-8")

    def cpus(self):
        with patch.object(CI.os, "cpu_count", return_value=8), \
                patch.object(CI.os, "sched_getaffinity", return_value=set(range(6)), create=True):
            return CI.available_cpus(self.root)

    def test_respects_affinity_without_cgroup_quota(self):
        self.assertEqual(self.cpus(), 6)

    def test_unified_cpu_quota_caps_visible_host_cpus(self):
        self.write("cpu.max", "400000 100000")
        self.assertEqual(self.cpus(), 4)

    def test_fractional_quota_can_use_its_remaining_cpu_time(self):
        self.write("cpu.max", "150000 100000")
        self.assertEqual(self.cpus(), 2)

    def test_unlimited_and_malformed_quotas_use_visible_cpus(self):
        for quota in ("max 100000", "bad quota", "400000 0", "", "too many fields here"):
            with self.subTest(quota=quota):
                self.write("cpu.max", quota)
                self.assertEqual(self.cpus(), 6)

    def test_legacy_cpu_quota(self):
        self.write("cpu/cpu.cfs_quota_us", "200000")
        self.write("cpu/cpu.cfs_period_us", "100000")
        self.assertEqual(self.cpus(), 2)

    def test_cpu_probe_fallbacks_keep_at_least_one_worker(self):
        with patch.object(CI.os, "cpu_count", return_value=None), \
                patch.object(CI.os, "sched_getaffinity", side_effect=OSError, create=True):
            self.assertEqual(CI.available_cpus(self.root), 1)

    def test_memory_uses_smaller_container_limit(self):
        self.write("memory.max", str(4 * GIB))
        with patch.object(CI, "host_memory", return_value=64 * GIB):
            self.assertEqual(CI.available_memory(self.root), 4 * GIB)

    def test_legacy_memory_and_unlimited_sentinel_do_not_inflate_host_memory(self):
        self.write("memory.max", "max")
        self.write("memory/memory.limit_in_bytes", str(2 ** 63 - 4096))
        with patch.object(CI, "host_memory", return_value=16 * GIB):
            self.assertEqual(CI.available_memory(self.root), 16 * GIB)
        self.write("memory/memory.limit_in_bytes", str(3 * GIB))
        with patch.object(CI, "host_memory", return_value=None):
            self.assertEqual(CI.available_memory(self.root), 3 * GIB)

    def test_unknown_memory_is_reported_without_inventing_a_limit(self):
        with patch.object(CI, "host_memory", return_value=None):
            self.assertIsNone(CI.available_memory(self.root))
        plan = CI.resource_plan(4, None)
        self.assertEqual(plan["CI_MEMORY_GIB"], "unknown")
        self.assertEqual(plan["CI_TEST_JOBS"], "4")

    def test_standard_public_linux_and_windows_runners_can_use_all_four_cpus(self):
        plan = CI.resource_plan(4, 16 * GIB)
        for name in ("CI_TEST_JOBS", "CI_BUILD_JOBS", "CARGO_BUILD_JOBS",
                     "CMAKE_BUILD_PARALLEL_LEVEL", "CTEST_PARALLEL_LEVEL", "RUST_TEST_THREADS"):
            self.assertEqual(plan[name], "4", name)

    def test_standard_public_mac_runner_can_use_all_three_cpus(self):
        plan = CI.resource_plan(3, 7 * GIB)
        self.assertEqual(plan["CI_TEST_JOBS"], "3")
        self.assertEqual(plan["CI_BUILD_JOBS"], "3")

    def test_small_memory_caps_tests_and_builds_separately(self):
        plan = CI.resource_plan(8, 4 * GIB)
        self.assertEqual(plan["CI_TEST_JOBS"], "1")
        self.assertEqual(plan["CI_BUILD_JOBS"], "2")
        plan = CI.resource_plan(4, GIB)
        self.assertEqual(plan["CI_TEST_JOBS"], "1")
        self.assertEqual(plan["CI_BUILD_JOBS"], "1")

    def test_configure_preserves_existing_gradle_options_in_github_env(self):
        target = self.root / "env"
        options = "-Dcustom.option=hello\nSECOND_LINE=value"
        with patch.dict(os.environ, {"GITHUB_ENV": str(target), "GRADLE_OPTS": options,
                                    "GITHUB_STEP_SUMMARY": ""}), \
                patch.object(CI, "available_cpus", return_value=4), \
                patch.object(CI, "available_memory", return_value=16 * GIB), \
                contextlib.redirect_stdout(io.StringIO()):
            CI.configure()
        # Decode the actual Actions multiline format, rather than relying on
        # implementation-specific delimiters or exposing Gradle options in logs.
        lines = iter(target.read_text().splitlines())
        values = {}
        for header in lines:
            key, delimiter = header.split("<<")
            body = []
            for line in lines:
                if line == delimiter:
                    break
                body.append(line)
            values[key] = "\n".join(body)
        self.assertEqual(values["CI_TEST_JOBS"], "4")
        self.assertEqual(values["GRADLE_OPTS"], options
                         + " -Dorg.gradle.parallel=true -Dorg.gradle.workers.max=4")
        self.assertNotIn("SECOND_LINE", values)


class MeasurementTests(unittest.TestCase):
    def test_wrapper_reports_and_preserves_child_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "summary.md"
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "run", "--label", "failed child", "--",
                 sys.executable, "-c", "print('child output'); raise SystemExit(7)"],
                env={**os.environ, "GITHUB_STEP_SUMMARY": str(report), "CI_CPU_COUNT": "4"},
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 7)
            self.assertIn("child output", result.stdout)
            self.assertIn("| 7 |", report.read_text())
            self.assertIn("failed child", report.read_text())

    def test_success_without_posix_resource_support_still_reports_elapsed(self):
        with patch.object(CI, "resource", None), patch.dict(os.environ, {"GITHUB_STEP_SUMMARY": ""}), \
                contextlib.redirect_stdout(io.StringIO()) as output:
            status = CI.run_measured("portable", [sys.executable, "-c", "pass"])
        self.assertEqual(status, 0)
        self.assertIn("| 0 |", output.getvalue())
        self.assertIn("| — | — | — |", output.getvalue())

    def test_missing_executable_is_a_failure_with_a_summary(self):
        with patch.object(CI.subprocess, "call", side_effect=FileNotFoundError("missing")), \
                patch.dict(os.environ, {"GITHUB_STEP_SUMMARY": ""}), \
                contextlib.redirect_stdout(io.StringIO()) as output, \
                contextlib.redirect_stderr(io.StringIO()):
            status = CI.run_measured("missing", ["missing"])
        self.assertEqual(status, 127)
        self.assertIn("| 127 |", output.getvalue())


if __name__ == "__main__":
    unittest.main()
