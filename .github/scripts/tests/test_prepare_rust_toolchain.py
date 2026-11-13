import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "prepare_rust_toolchain.py"
SPEC = importlib.util.spec_from_file_location("prepare_rust_toolchain", SCRIPT)
RUST = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUST)


class PrepareRustToolchainTests(unittest.TestCase):
    def test_healthy_toolchain_is_not_uninstalled(self):
        with patch.object(RUST.subprocess, "run") as run:
            RUST.prepare_toolchain("1.92.0", ["aarch64-apple-ios"])
        commands = [call.args[0] for call in run.call_args_list]
        self.assertFalse(any("uninstall" in command for command in commands))
        self.assertIn(["rustup", "run", "1.92.0", "cargo", "--version"], commands)
        self.assertIn(["rustup", "run", "1.92.0", "rustc", "--version"], commands)

    def test_failures_surface_without_resetting_or_reinstalling_the_toolchain(self):
        for failing_call in range(3):
            with self.subTest(failing_call=failing_call):
                failure = subprocess.CalledProcessError(1, "rustup")
                outcomes = [*([None] * failing_call), failure]
                with patch.object(RUST.subprocess, "run", side_effect=outcomes) as run:
                    with self.assertRaises(subprocess.CalledProcessError) as raised:
                        RUST.prepare_toolchain("1.92.0", ["aarch64-apple-ios"])
                self.assertIs(raised.exception, failure)
                commands = [call.args[0] for call in run.call_args_list]
                self.assertFalse(any("uninstall" in command for command in commands))
                self.assertEqual(run.call_count, failing_call + 1)

    def test_workflow_exports_only_the_successfully_prepared_toolchain(self):
        for failed in (False, True):
            with self.subTest(failed=failed), tempfile.TemporaryDirectory() as temporary:
                github_env = Path(temporary) / "github env"
                github_env.write_text("EXISTING=value\n", encoding="utf-8")
                with (
                    patch.dict(os.environ, {"GITHUB_ENV": str(github_env)}),
                    patch("sys.argv", [str(SCRIPT), "--version", "1.92.0"]),
                    patch.object(
                        RUST, "prepare_toolchain", side_effect=(
                            subprocess.CalledProcessError(1, "rustup") if failed else None
                        ),
                    ),
                ):
                    if failed:
                        with self.assertRaises(subprocess.CalledProcessError):
                            RUST.main()
                    else:
                        RUST.main()
                expected = "EXISTING=value\n" + ("" if failed else "RUSTUP_TOOLCHAIN=1.92.0\n")
                self.assertEqual(github_env.read_text(encoding="utf-8"), expected)


if __name__ == "__main__":
    unittest.main()
