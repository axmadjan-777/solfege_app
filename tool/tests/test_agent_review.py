"""Offline acceptance of the review boundary using only an explicit fake Codex.

Every Git operation targets a temporary fixture repository. No model, account,
network service, real credential, or production evidence is accessed.
"""

import base64
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


FAKE_CODEX = r'''
#!/usr/bin/env python3
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

AUDIT = Path(__AUDIT__)
REPO = Path(__REPO__)
directory = Path.cwd()
arguments = sys.argv[1:]
target = json.loads((directory / "target.json").read_text())
scenario = json.loads((directory / "source/review-scenario.json").read_text())
behavior = scenario["behavior"]
audit = {
    "cwd": str(directory), "arguments": arguments,
    "files": sorted(str(p.relative_to(directory)) for p in directory.rglob("*") if p.is_file()),
    "stagedApp": (directory / "source/app.txt").read_text(),
    "diff": (directory / "staged.diff").read_text(),
    "secretEnvPresent": any(name in os.environ for name in ("QA_USER_A_PASSWORD", "QA_SUPABASE_PUBLISHABLE_KEY", "OPENAI_API_KEY")),
    "recursiveGuard": os.environ.get("AGENT_REVIEW_ACTIVE"),
}
AUDIT.write_text(json.dumps(audit))
if behavior == "timeout":
    time.sleep(30)
observations = {}
for kind in ("tests", "visual", "live"):
    evidence = [{"path": item["path"], "detail": "Inspected the explicit fixture evidence file."} for item in target["evidence"] if item["kind"] == kind]
    observations[kind] = {"status": "observed_pass" if evidence else "not_observed", "evidence": evidence, "detail": "Fixture evidence inspected." if evidence else "No evidence supplied for this category."}
report = {"schemaVersion": 1, "reviewer": "independent_codex_cli", **{key: target[key] for key in ("baseSha", "stagedTreeSha", "model", "reasoningEffort", "reviewRound")}, "status": "pass", "summary": "Independent fixture report for harness safety testing.", "findings": [], "observations": observations, "limitations": ["This is an offline fake-Codex safety test, not a real model review."]}
finding = {"priority": "P1", "title": "Fixture behavior regression", "body": "The staged fixture changes its accepted value and breaks the stated acceptance requirement.", "location": {"path": "source/app.txt", "line": 1}, "evidence": [{"path": "source/app.txt", "detail": "The fixture contains the changed staged value."}]}
if behavior in ("changes_requested", "pass_with_findings"):
    report["findings"] = [finding]
if behavior == "changes_requested":
    report["status"] = "changes_requested"
if behavior == "blocked":
    report["status"] = "blocked"
    report["summary"] = "Fixture reviewer cannot establish the required acceptance evidence."
if behavior == "wrong_target":
    report["stagedTreeSha"] = "f" * len(target["stagedTreeSha"])
if behavior == "wrong_model":
    report["model"] = "another-model"
if behavior == "wrong_origin":
    report["reviewer"] = "independent_native_agent"
if behavior == "extra_field":
    report["unexpected"] = "unvalidated output"
if behavior == "observed_without_evidence":
    report["observations"]["tests"]["evidence"] = []
if behavior == "mixed_evidence":
    report["observations"]["visual"] = {"status": "observed_pass", "evidence": report["observations"]["tests"]["evidence"], "detail": "This incorrectly treats a test log as a visual observation."}
if behavior == "observed_failure":
    report["observations"]["tests"]["status"] = "observed_fail"
if behavior == "out_of_snapshot":
    report["status"] = "changes_requested"
    report["findings"] = [finding]
    finding["location"]["path"] = "source/../../.qa/live.json"
if behavior == "invalid_line":
    report["status"] = "changes_requested"
    report["findings"] = [finding]
    finding["location"]["line"] = 999999
if behavior == "mutate_target":
    (REPO / "app.txt").write_text("concurrent staged update\n")
    subprocess.run(["git", "add", "app.txt"], cwd=REPO, check=True)
if behavior == "mutate_base":
    commit = subprocess.run(["git", "commit-tree", target["stagedTreeSha"], "-p", target["baseSha"], "-m", "Concurrent fixture base update"], cwd=REPO, check=True, text=True, capture_output=True).stdout.strip()
    subprocess.run(["git", "update-ref", "refs/remotes/origin/main", commit], cwd=REPO, check=True)
if behavior == "mutate_snapshot":
    (directory / "source/app.txt").write_text("mutated snapshot\n")
if behavior == "mutate_evidence":
    (REPO / "build/tests.json").write_text('{"status":"failed"}')
output = Path(arguments[arguments.index("--output-last-message") + 1])
if behavior == "missing_report":
    sys.exit(0)
if behavior == "empty_report":
    output.write_text("")
elif behavior == "invalid_json":
    output.write_text("not JSON")
else:
    output.write_text(json.dumps(report))
if behavior == "cli_failure":
    sys.exit(42)
'''


class AgentReviewSafetyTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.repo = self.directory / "repo with spaces"
        self.repo.mkdir()
        for relative in (
            "tool/agent_review.sh", "tool/agent_review.schema.json",
            "tool/prompts/qa-review.md", "tool/qa_scope.py",
            ".codex/agents/qa-reviewer.toml",
        ):
            target = self.repo / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        (self.repo / ".gitignore").write_text("/build/\n/.qa/\ndart_defines.json\nignored.txt\n")
        (self.repo / "app.txt").write_text("base\n")
        (self.repo / "README.md").write_text("Fixture documentation.\n")
        (self.repo / "review-scenario.json").write_text('{"behavior":"pass"}')
        self.git("init", "-q")
        self.git("config", "user.name", "Offline QA fixture")
        self.git("config", "user.email", "qa@example.invalid")
        self.git("add", ".gitignore", "app.txt", "README.md", "review-scenario.json", "tool", ".codex")
        self.git("commit", "-qm", "Fixture base")
        self.base = self.git("rev-parse", "HEAD").strip()
        (self.repo / "app.txt").write_text("staged\n")
        self.git("add", "app.txt")
        (self.repo / "app.txt").write_text("unstaged-content-must-not-reach-reviewer\n")
        (self.repo / ".qa").mkdir()
        (self.repo / ".qa/live.json").write_text('{"password":"ignored-secret-sentinel"}')
        (self.repo / "dart_defines.json").write_text('{"key":"ignored-config-sentinel"}')
        (self.repo / "ignored.txt").write_text("ignored-file-sentinel")
        (self.repo / "build").mkdir()
        (self.repo / "build/tests.json").write_text('{"status":"passed","command":"fixture targeted tests","count":3}')
        self.audit = self.directory / "audit.json"
        self.fake = self.directory / "fake-codex"
        self.fake.write_text(FAKE_CODEX.lstrip().replace("__AUDIT__", repr(str(self.audit))).replace("__REPO__", repr(str(self.repo))))
        self.fake.chmod(0o700)
        self.scratch = self.directory / "temporary snapshots"
        self.scratch.mkdir()
        self.home = self.directory / "empty home"
        self.home.mkdir()
        self.environment = {
            "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
            "HOME": str(self.home), "CODEX_HOME": str(self.home / ".codex"),
            "CODEX_BIN": str(self.fake), "TMPDIR": str(self.scratch),
            "QA_USER_A_PASSWORD": "parent-env-secret-sentinel",
            "QA_SUPABASE_PUBLISHABLE_KEY": "parent-publishable-secret-sentinel",
            "OPENAI_API_KEY": "parent-api-secret-sentinel",
        }

    def git(self, *arguments):
        result = subprocess.run(["git", *arguments], cwd=self.repo, check=True, text=True, capture_output=True)
        return result.stdout

    def behavior(self, name):
        (self.repo / "review-scenario.json").write_text(json.dumps({"behavior": name}))
        self.git("add", "review-scenario.json")

    def run_review(self, expected=0, extra=(), evidence=True, environment=None):
        arguments = ["bash", "tool/agent_review.sh"]
        if evidence:
            arguments += ["--evidence", "tests=build/tests.json"]
        arguments += list(extra)
        result = subprocess.run(arguments, cwd=self.repo, env=environment or self.environment, text=True, capture_output=True, timeout=30, check=False)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        for secret in ("parent-env-secret-sentinel", "parent-api-secret-sentinel", "ignored-secret-sentinel", "ignored-config-sentinel"):
            self.assertNotIn(secret, result.stdout + result.stderr)
        manifest = json.loads((self.repo / "build/agent-review/manifest.json").read_text())
        report_path = self.repo / "build/agent-review/report.json"
        report = json.loads(report_path.read_text()) if report_path.exists() else None
        self.assertFalse(list(self.scratch.glob("solfege-agent-review-*")), "Temporary snapshots must be removed on every outcome")
        return manifest, report

    def assert_blocked(self, manifest, report):
        self.assertEqual(manifest["status"], "blocked")
        self.assertIsNotNone(report)
        self.assertEqual(report["status"], "blocked")
        self.assertNotEqual(report["status"], "pass")

    def test_pass_reviews_only_staged_snapshot_with_explicit_read_only_contract(self):
        manifest, report = self.run_review(extra=("--base", self.base, "--round", "2"))
        self.assertEqual(report["status"], "pass")
        self.assertEqual(report["reviewer"], "independent_codex_cli")
        self.assertEqual(report["baseSha"], self.base)
        self.assertEqual(report["stagedTreeSha"], self.git("write-tree").strip())
        self.assertEqual(report["reviewRound"], 2)
        self.assertTrue(manifest["reviewerInvoked"] and manifest["reportValidated"] and manifest["targetUnchanged"])
        audit = json.loads(self.audit.read_text())
        self.assertEqual(audit["stagedApp"], "staged\n")
        self.assertNotIn("unstaged-content", audit["diff"])
        self.assertFalse(audit["secretEnvPresent"])
        self.assertEqual(audit["recursiveGuard"], "1")
        self.assertFalse(any(".qa/" in name or "dart_defines.json" in name or name == "source/ignored.txt" or name.startswith(".git/") for name in audit["files"]))
        self.assertFalse(Path(audit["cwd"]).exists())
        args = audit["arguments"]
        self.assertIn("--ignore-user-config", args)
        self.assertIn("--ignore-rules", args)
        self.assertIn("--ephemeral", args)
        self.assertIn("--skip-git-repo-check", args)
        self.assertEqual(args[args.index("--sandbox") + 1], "read-only")
        self.assertEqual(args[args.index("--model") + 1], "gpt-6.1-sol")
        self.assertIn('model_reasoning_effort="high"', args)
        self.assertIn('approval_policy="never"', args)
        self.assertIn("agents.enabled=false", args)

    def test_actionable_changes_and_honest_blocked_are_not_pass(self):
        for behavior, code in (("changes_requested", 1), ("blocked", 2)):
            with self.subTest(behavior=behavior):
                self.behavior(behavior)
                manifest, report = self.run_review(expected=code)
                self.assertEqual(report["status"], behavior)
                self.assertEqual(report["reviewer"], "independent_codex_cli")
                self.assertTrue(manifest["reportValidated"])

    def test_base_ref_is_resolved_to_sha_and_cannot_move_during_review(self):
        self.git("update-ref", "refs/remotes/origin/main", self.base)
        manifest, report = self.run_review(extra=("--base", "origin/main"))
        self.assertEqual(report["baseSha"], self.base)
        self.assertTrue(manifest["targetUnchanged"])
        self.behavior("mutate_base")
        manifest, report = self.run_review(expected=2, extra=("--base", "origin/main"))
        self.assert_blocked(manifest, report)
        self.assertFalse(manifest["targetUnchanged"])

    def test_cli_failure_cannot_accept_even_a_valid_pass_report(self):
        self.behavior("cli_failure")
        manifest, report = self.run_review(expected=2)
        self.assert_blocked(manifest, report)
        self.assertEqual(manifest["codexExitCode"], 42)
        self.assertEqual(report["reviewer"], "harness")

    def test_missing_empty_invalid_or_wrong_identity_reports_fail_closed(self):
        for behavior in ("missing_report", "empty_report", "invalid_json", "wrong_target", "wrong_model", "wrong_origin", "extra_field"):
            with self.subTest(behavior=behavior):
                self.behavior(behavior)
                self.assert_blocked(*self.run_review(expected=2))

    def test_unfounded_observations_findings_and_evidence_locations_cannot_pass(self):
        for behavior in ("pass_with_findings", "observed_without_evidence", "mixed_evidence", "observed_failure", "out_of_snapshot", "invalid_line"):
            with self.subTest(behavior=behavior):
                self.behavior(behavior)
                self.assert_blocked(*self.run_review(expected=2))

    def test_concurrent_target_snapshot_and_evidence_mutations_fail_closed(self):
        for behavior in ("mutate_target", "mutate_snapshot", "mutate_evidence"):
            with self.subTest(behavior=behavior):
                self.behavior(behavior)
                (self.repo / "build/tests.json").write_text('{"status":"passed"}')
                manifest, report = self.run_review(expected=2)
                self.assert_blocked(manifest, report)
                self.assertFalse(manifest["targetUnchanged"])

    def test_timeout_kills_reviewer_and_removes_temporary_snapshot(self):
        self.behavior("timeout")
        manifest, report = self.run_review(expected=2, extra=("--timeout-seconds", "1"))
        self.assert_blocked(manifest, report)
        self.assertIn("timeout", manifest["reason"])

    def test_missing_codex_and_missing_test_evidence_remove_old_pass(self):
        self.run_review()
        missing = {**self.environment, "CODEX_BIN": str(self.directory / "missing-codex")}
        manifest, report = self.run_review(expected=2, environment=missing)
        self.assert_blocked(manifest, report)
        self.assertFalse(manifest["reviewerInvoked"])
        manifest, report = self.run_review(expected=2, evidence=False)
        self.assert_blocked(manifest, report)
        self.assertFalse(manifest["reviewerInvoked"])

    def test_ordinary_docs_only_exempts_model_but_agents_policy_does_not(self):
        self.git("reset", "--mixed", "HEAD")
        (self.repo / "README.md").write_text("Changed ordinary documentation.\n")
        self.git("add", "README.md")
        manifest, report = self.run_review(evidence=False)
        self.assertEqual(manifest["status"], "not_required")
        self.assertFalse(manifest["reviewerInvoked"])
        self.assertIsNone(report)
        self.assertFalse(self.audit.exists())
        self.git("reset", "--mixed", "HEAD")
        (self.repo / "AGENTS.md").write_text("Changed permanent agent policy.\n")
        self.git("add", "AGENTS.md")
        manifest, report = self.run_review()
        self.assertEqual(report["status"], "pass")
        self.assertTrue(manifest["reviewerInvoked"])

    def test_empty_staged_target_is_blocked(self):
        self.git("reset", "--mixed", "HEAD")
        self.assert_blocked(*self.run_review(expected=2))
        self.assertFalse(self.audit.exists())

    def test_secret_tracked_paths_and_symlinks_never_reach_reviewer(self):
        self.git("add", "-f", ".qa/live.json")
        self.assert_blocked(*self.run_review(expected=2))
        self.assertFalse(self.audit.exists())
        self.git("reset", "HEAD", "--", ".qa/live.json")
        (self.repo / "secret-link").symlink_to(self.repo / ".qa/live.json")
        self.git("add", "secret-link")
        self.assert_blocked(*self.run_review(expected=2))
        self.assertFalse(self.audit.exists())

    def test_evidence_requires_safe_explicit_build_files(self):
        (self.repo / "build/empty.json").write_text("")
        (self.repo / "build/credential.json").write_text('{"password":"evidence-secret-sentinel"}')
        (self.repo / "build/link.json").symlink_to(self.repo / ".qa/live.json")
        for evidence in ("live=.qa/live.json", "live=build/link.json", "tests=build/credential.json", "tests=build/missing.json", "tests=build/empty.json", "live=build/../.qa/live.json"):
            with self.subTest(evidence=evidence):
                self.assert_blocked(*self.run_review(expected=2, extra=("--evidence", evidence)))
                self.assertFalse(self.audit.exists())

    def test_failed_or_preflight_only_summary_cannot_support_a_pass(self):
        for summary in ({"status": "failed"}, {"mode": "preflight", "status": "preflight_passed", "liveAcceptance": "not_run"}):
            (self.repo / "build/live.json").write_text(json.dumps(summary))
            self.assert_blocked(*self.run_review(expected=2, extra=("--evidence", "live=build/live.json")))
        for xml in ('<testsuites><testsuite tests="3" failures="1"/></testsuites>', '<testsuite tests="0" failures="0"/>'):
            (self.repo / "build/results.xml").write_text(xml)
            self.assert_blocked(*self.run_review(expected=2, extra=("--evidence", "tests=build/results.xml")))

    def test_explicit_visual_image_is_attached_and_categories_stay_distinct(self):
        png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII="
        (self.repo / "build/screen.png").write_bytes(base64.b64decode(png))
        manifest, report = self.run_review(extra=("--evidence", "visual=build/screen.png"))
        self.assertEqual(report["observations"]["visual"]["status"], "observed_pass")
        self.assertEqual(report["observations"]["live"]["status"], "not_observed")
        self.assertEqual([item["kind"] for item in manifest["evidence"]], ["tests", "visual"])
        self.assertIn("-i", json.loads(self.audit.read_text())["arguments"])

    def test_round_limit_and_recursive_review_do_not_invoke_model(self):
        result = subprocess.run(["bash", "tool/agent_review.sh", "--round", "3"], cwd=self.repo, env=self.environment, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 2)
        recursive = {**self.environment, "AGENT_REVIEW_ACTIVE": "1"}
        result = subprocess.run(["bash", "tool/agent_review.sh"], cwd=self.repo, env=recursive, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 2)
        self.assertFalse(self.audit.exists())


if __name__ == "__main__":
    unittest.main()
