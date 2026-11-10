import base64
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import tempfile
import textwrap
import unittest


WORKFLOW = Path(__file__).resolve().parents[2] / "workflows/build.yml"


def signing_step(name):
    workflow = WORKFLOW.read_text(encoding="utf-8")
    step = workflow.split(f"      - name: {name}\n", 1)[1]
    step = re.split(r"\n      - |\n  \w", step, maxsplit=1)[0]
    run = step.split("        run: ", 1)[1]
    return textwrap.dedent(run[2:]) if run.startswith("|\n") else run.strip()


@unittest.skipIf(os.name == "nt" or not shutil.which("bash"), "Signing runs on Linux.")
class AndroidSigningTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="android signing ")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.checkout = self.root / "checkout"
        self.checkout.mkdir()
        self.runner = self.root / "runner temp"
        self.runner.mkdir()
        self.github_env = self.root / "github-env"
        self.keystore = b"\xfe\xed\xfe\xed\x00\x00\x00\x02synthetic keystore bytes"
        self.properties = (
            "storeFile=keystore.jks\r\n"
            "storePassword=literal$(touch leaked)'\\password\r\n"
            "keyAlias=example\r\nkeyPassword=another$literal\r\n"
        )
        self.env = dict(
            os.environ,
            RUNNER_TEMP=str(self.runner),
            GITHUB_ENV=str(self.github_env),
            ANDROID_KEYSTORE=base64.encodebytes(self.keystore).decode(),
            ANDROID_KEY_PROPERTIES=self.properties,
        )

    def run_step(self, name, env=None):
        return subprocess.run(
            ["bash", "-e", "-o", "pipefail", "-c", signing_step(name)],
            cwd=self.checkout, env=self.env if env is None else env,
            capture_output=True, text=True, timeout=10,
        )

    def cleanup_signing(self):
        result = self.run_step("清理临时 Android 签名文件")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.runner / "android-signing").exists())

    def test_secrets_are_preserved_privately_outside_checkout_then_removed(self):
        result = self.run_step("准备临时 Android 签名文件")
        self.assertEqual(result.returncode, 0, result.stderr)
        paths = dict(line.split("=", 1) for line in self.github_env.read_text().splitlines())
        keystore = Path(paths["ANDROID_KEYSTORE_FILE"])
        properties = Path(paths["ANDROID_KEY_PROPERTIES_FILE"])
        self.assertEqual(keystore.read_bytes(), self.keystore)
        self.assertEqual(properties.read_bytes(), self.properties.encode())
        for path in (keystore, properties):
            self.assertTrue(path.is_relative_to(self.runner))
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(keystore.parent.stat().st_mode), 0o700)
        self.assertEqual(list(self.checkout.iterdir()), [])
        self.assertEqual(result.stdout + result.stderr, "")
        self.cleanup_signing()

    def test_missing_secrets_fail_before_writing_files(self):
        for name in ("ANDROID_KEYSTORE", "ANDROID_KEY_PROPERTIES"):
            with self.subTest(secret=name):
                env = self.env.copy()
                env.pop(name)
                result = self.run_step("准备临时 Android 签名文件", env)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Secrets", result.stderr)
                self.assertFalse(self.github_env.exists())
                self.cleanup_signing()

    def test_invalid_or_empty_base64_fails_and_partial_files_can_be_cleaned(self):
        for value in ("cGFydGlhbA==!", "\n"):
            with self.subTest(base64=value):
                env = dict(self.env, ANDROID_KEYSTORE=value)
                result = self.run_step("准备临时 Android 签名文件", env)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.github_env.exists())
                self.assertNotIn(self.properties, result.stdout + result.stderr)
                self.cleanup_signing()
