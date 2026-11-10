import hashlib
import os
from pathlib import Path
import shutil
import ssl
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1] / "AndroidSigningIdentity.java"


@unittest.skipUnless(shutil.which("java") and shutil.which("keytool"), "Requires JDK 17+")
class SigningIdentityTests(unittest.TestCase):
    def test_real_jks_and_pkcs12_certificates_match_java_properties_escaping(self):
        for store_type in ("JKS", "PKCS12"):
            with self.subTest(store_type=store_type), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                store, properties = root / "keystore.jks", root / "key.properties"
                password, alias = "p:a\\ss!word", "signer alias"
                environment = dict(os.environ, CI_TEST_KEYSTORE_PASSWORD=password,
                                   ANDROID_KEYSTORE_FILE=str(store), ANDROID_KEY_PROPERTIES_FILE=str(properties))
                subprocess.run(["keytool", "-genkeypair", "-noprompt", "-keystore", str(store),
                                "-storetype", store_type, "-storepass:env", "CI_TEST_KEYSTORE_PASSWORD",
                                "-keypass:env", "CI_TEST_KEYSTORE_PASSWORD", "-alias", alias,
                                "-dname", "CN=CI test", "-keyalg", "RSA", "-validity", "1"],
                               env=environment, check=True, capture_output=True)
                certificate = subprocess.check_output(["keytool", "-exportcert", "-rfc", "-keystore", str(store),
                                                        "-storepass:env", "CI_TEST_KEYSTORE_PASSWORD", "-alias", alias],
                                                       env=environment, text=True, stderr=subprocess.DEVNULL)
                expected = hashlib.sha256(ssl.PEM_cert_to_DER_cert(certificate)).hexdigest()
                properties.write_text("storeFile=ignored-in-ci.jks\nstorePassword=p\\:a\\\\ss!word\nkeyAlias=signer\\ alias\n")
                result = subprocess.run(["java", str(SOURCE)], env=environment, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), expected)
                self.assertNotIn(password, result.stdout + result.stderr)

                for invalid in ("storePassword=wrong\nkeyAlias=signer alias\n",
                                "storePassword=p\\:a\\\\ss!word\nkeyAlias=missing\n"):
                    properties.write_text(invalid)
                    failed = subprocess.run(["java", str(SOURCE)], env=environment, text=True, capture_output=True)
                    self.assertNotEqual(failed.returncode, 0)
                    self.assertEqual(failed.stdout, "")
                    self.assertNotIn(password, failed.stderr)
