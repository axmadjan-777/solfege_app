"""Offline checks that SDK bootstrap failures cannot look like live acceptance."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[2]


class VerifyLiveBootstrapTests(unittest.TestCase):
    def test_missing_report_path_cannot_consume_preflight_and_start_live(self):
        result = subprocess.run(
            ["bash", "tool/verify_live.sh", "--report-dir", "--preflight"],
            cwd=ROOT,
            env={"PATH": os.environ.get("PATH", "/usr/bin:/bin")},
            text=True,
            capture_output=True,
            timeout=10,
            check=False,
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("Usage:", result.stderr)

    def run_wrapper(self, directory: Path, deno_bin: Path):
        report = directory / "reports with spaces"
        report.mkdir()
        (report / "gemini-evaluation.json").write_text(
            '{"answer":"stale result must not survive a failed run"}', encoding="utf-8"
        )
        environment = {
            "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
            "HOME": str(directory),
            "DENO_BIN": str(deno_bin),
            "QA_USER_A_PASSWORD": "bootstrap-secret-sentinel",
        }
        result = subprocess.run(
            ["bash", "tool/verify_live.sh", "--preflight", "--report-dir", str(report)],
            cwd=ROOT,
            env=environment,
            text=True,
            capture_output=True,
            timeout=20,
            check=False,
        )
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertNotIn("bootstrap-secret-sentinel", result.stdout + result.stderr)
        summary = json.loads((report / "summary.json").read_text(encoding="utf-8"))
        self.assertEqual(summary["status"], "configuration_error")
        self.assertEqual(summary["liveAcceptance"], "not_run")
        self.assertEqual(summary["exitCode"], 2)
        self.assertFalse((report / "gemini-evaluation.json").exists())
        suite = ET.parse(report / "results.junit.xml").find("testsuite")
        self.assertIsNotNone(suite)
        self.assertEqual(suite.attrib["failures"], "1")
        self.assertEqual(suite.attrib["skipped"], "0")

    def test_missing_sdk_produces_failure_artifacts(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            self.run_wrapper(directory, directory / "nonexistent-deno")

    def test_wrong_sdk_is_rejected_before_running_any_test(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            fake_sdk = directory / "wrong-deno"
            calls = directory / "sdk-calls"
            fake_sdk.write_text(
                '#!/bin/sh\n'
                f'printf "%s\\n" "$1" >> "{calls}"\n'
                'printf "deno 0.0.0\\n"\n',
                encoding="utf-8",
            )
            fake_sdk.chmod(0o700)
            self.run_wrapper(directory, fake_sdk)
            self.assertEqual(calls.read_text(encoding="utf-8"), "--version\n")


if __name__ == "__main__":
    unittest.main()
