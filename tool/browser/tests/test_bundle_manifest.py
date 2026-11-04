"""Provenance checks use only synthetic files, without Flutter or credentials."""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


class BundleManifestTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="solfege-bundle-test-")
        self.root = Path(self.temporary.name)
        self.script = self.root / "tool/browser/bundle_manifest.py"
        self.script.parent.mkdir(parents=True)
        shutil.copyfile(Path(__file__).resolve().parents[1] / "bundle_manifest.py", self.script)
        for directory in ("lib", "assets", "web", "tool/browser/fonts"):
            destination = self.root / directory
            destination.mkdir(parents=True, exist_ok=True)
            (destination / "fixture").write_text("synthetic source")
        for name in ("pubspec.yaml", "pubspec.lock", "test_driver/qa_main.dart",
                     "tool/toolchain.env", "tool/browser/prepare_web.py"):
            destination = self.root / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text("synthetic source")
        self.bundle = self.root / "build/qa-web"
        self.bundle.mkdir(parents=True)
        (self.bundle / "main.dart.js").write_text("synthetic compiled bundle")
        self.environment = {"PATH": os.defpath, "QA_SOURCE_TREE": "a" * 40}

    def tearDown(self):
        self.temporary.cleanup()

    def command(self, *args, check=True, environment=None):
        result = subprocess.run(
            [sys.executable, str(self.script), *args], cwd=self.root,
            env=environment or self.environment, text=True, capture_output=True,
        )
        if check:
            self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def create(self):
        fingerprint = self.command("inputs").stdout.strip()
        self.command("create", "--flutter=3.47.6", "--optimization-level=4",
                     f"--expected-inputs={fingerprint}")

    def verify(self, **kwargs):
        return self.command("check", "--flutter=3.47.6", "--optimization-level=4", **kwargs)

    def test_reuse_accepts_exact_source_and_bundle_without_sdk(self):
        self.create()
        self.assertIn("PASS", self.verify().stdout)

    def test_reuse_rejects_changed_runtime_inputs(self):
        self.create()
        (self.root / "lib/fixture").write_text("changed source")
        result = self.verify(check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("source_inputs_sha256", result.stderr)

    def test_reuse_rejects_tampered_bundle(self):
        self.create()
        (self.bundle / "main.dart.js").write_text("changed bundle")
        result = self.verify(check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("bundle_sha256", result.stderr)

    def test_reuse_rejects_different_source_tree(self):
        self.create()
        environment = {"PATH": os.defpath, "QA_SOURCE_TREE": "b" * 40}
        result = self.verify(check=False, environment=environment)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("source_tree", result.stderr)

    def test_create_rejects_inputs_changed_during_build(self):
        before = self.command("inputs").stdout.strip()
        (self.root / "lib/fixture").write_text("changed during compilation")
        result = self.command("create", "--flutter=3.47.6",
                              f"--expected-inputs={before}", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("changed during compilation", result.stderr)
        self.assertFalse((self.root / "build/browser-run.json").exists())


if __name__ == "__main__":
    unittest.main()
