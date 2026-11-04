"""Integration checks for the Git gate, using disposable repositories only."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class StagedQATest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="solfege qa test ")
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
        self.env["GIT_CONFIG_GLOBAL"] = os.devnull
        self.env["GIT_CONFIG_NOSYSTEM"] = "1"
        self.env["QA_TEST_REPO"] = str(self.repo)
        for name in (
            "tool/qa_staged.sh", "tool/install_hooks.sh", "tool/toolchain.sh",
            "tool/toolchain.env", "tool/qa_scope.py", ".githooks/pre-commit",
        ):
            target = self.repo / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, target)
        (self.repo / "tool/verify.sh").write_text(
            '#!/usr/bin/env bash\nset -euo pipefail\n'
            'test -z "${GIT_INDEX_FILE:-}"\n'
            'test "$(cat payload.txt)" = good\n'
            'printf verified > qa-artifact.txt\n'
        )
        (self.repo / "payload.txt").write_text("good\n")
        self.git("init", "--quiet")
        self.git("config", "user.name", "QA Fixture")
        self.git("config", "user.email", "qa@example.invalid")
        self.git("add", "tool", ".githooks", "payload.txt")

    def run_command(self, *args):
        return subprocess.run(
            args, cwd=self.repo, env=self.env,
            text=True, capture_output=True, timeout=30,
        )

    def git(self, *args):
        result = self.run_command("git", *args)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout.strip()

    def qa(self):
        return self.run_command("bash", "tool/qa_staged.sh")

    def test_staged_failure_is_not_hidden_by_unstaged_fix(self):
        (self.repo / "payload.txt").write_text("bad\n")
        self.git("add", "payload.txt")
        (self.repo / "payload.txt").write_text("good\n")
        self.assertNotEqual(self.qa().returncode, 0)

    def test_unstaged_breakage_and_artifacts_do_not_affect_staged_check(self):
        (self.repo / "payload.txt").write_text("bad\n")
        before = self.git("write-tree")
        result = self.qa()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.git("write-tree"), before)
        self.assertFalse((self.repo / "qa-artifact.txt").exists())
        self.assertEqual((self.repo / "payload.txt").read_text(), "bad\n")

    def test_hook_rejects_actual_commit_without_creating_head(self):
        installed = self.run_command("bash", "tool/install_hooks.sh")
        self.assertEqual(installed.returncode, 0, installed.stderr)
        (self.repo / "payload.txt").write_text("bad\n")
        self.git("add", "payload.txt")
        result = self.run_command("git", "commit", "-m", "fixture must fail")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("QA staged tree:", result.stdout + result.stderr)
        self.assertNotEqual(self.run_command("git", "rev-parse", "--verify", "HEAD").returncode, 0)

    def test_changed_index_requires_another_qa_run(self):
        (self.repo / "tool/verify.sh").write_text(
            '#!/usr/bin/env bash\nset -euo pipefail\n'
            'git -C "$QA_TEST_REPO" update-index --force-remove payload.txt\n'
        )
        self.git("add", "tool/verify.sh")
        result = self.qa()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("индекс изменился", result.stderr)

    def test_installer_preserves_an_existing_hooks_path(self):
        self.git("config", "core.hooksPath", "custom-hooks")
        result = self.run_command("bash", "tool/install_hooks.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.git("config", "--get", "core.hooksPath"), "custom-hooks")

    def test_missing_staged_harness_fails_explicitly(self):
        self.git("rm", "--cached", "tool/verify.sh")
        result = self.qa()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("отсутствует в подготовленном коммите", result.stderr)

    def test_docs_commit_uses_light_qa_on_the_staged_snapshot(self):
        # Use the real light checker, not the full-QA stand-in above.
        for name in ("tool/verify.sh", "tool/verify_docs.py"):
            shutil.copy2(ROOT / name, self.repo / name)
        (self.repo / "README.md").write_text("Documentation\n")
        (self.repo / "AGENTS.md").write_text("Instructions\n")
        self.git("add", "tool", "README.md", "AGENTS.md")
        self.git("commit", "--quiet", "-m", "fixture baseline")
        baseline = self.git("rev-parse", "HEAD")
        (self.repo / "README.md").write_text("[missing](missing.md)\n")
        self.git("add", "README.md")
        self.env["FLUTTER_BIN"] = "/missing/flutter"
        self.env["DENO_BIN"] = "/missing/deno"
        installed = self.run_command("bash", "tool/install_hooks.sh")
        self.assertEqual(installed.returncode, 0, installed.stderr)
        rejected = self.run_command("git", "commit", "-m", "fixture broken docs")
        self.assertNotEqual(rejected.returncode, 0)
        self.assertIn("не найден путь ссылки", rejected.stdout + rejected.stderr)
        self.assertEqual(self.git("rev-parse", "HEAD"), baseline)

        (self.repo / "README.md").write_text("[valid](payload.txt)\n")
        self.git("add", "README.md")
        # An unstaged broken link must not affect the prepared commit.
        (self.repo / "README.md").write_text("[missing](missing.md)\n")
        result = self.run_command("git", "commit", "-m", "fixture docs")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("QA scope: docs", result.stdout + result.stderr)
        self.assertEqual(self.git("show", "HEAD:README.md"), "[valid](payload.txt)")
        self.assertEqual((self.repo / "README.md").read_text(), "[missing](missing.md)\n")
        self.assertFalse((self.repo / "qa-artifact.txt").exists())

    def test_rename_from_code_to_docs_cannot_select_light_qa(self):
        (self.repo / "source.dart").write_text("code\n")
        self.git("add", "source.dart")
        self.git("commit", "--quiet", "-m", "fixture baseline")
        (self.repo / "docs").mkdir()
        self.git("mv", "source.dart", "docs/source.md")
        result = self.qa()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("QA scope: full", result.stdout)
        self.assertNotIn("--docs-only", result.stdout)

    def test_unstaged_classifier_cannot_hide_a_staged_failure(self):
        self.git("commit", "--quiet", "-m", "fixture baseline")
        (self.repo / "payload.txt").write_text("bad\n")
        self.git("add", "payload.txt")
        (self.repo / "tool/qa_scope.py").write_text('print("docs")\n')
        result = self.qa()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("QA scope: full", result.stdout)

    def test_light_qa_still_rejects_index_changes(self):
        with (self.repo / "tool/verify.sh").open("a") as script:
            script.write('git -C "$QA_TEST_REPO" update-index --force-remove payload.txt\n')
        self.git("add", "tool/verify.sh")
        self.git("commit", "--quiet", "-m", "fixture baseline")
        (self.repo / "README.md").write_text("Documentation\n")
        self.git("add", "README.md")
        result = self.qa()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("QA scope: docs", result.stdout)
        self.assertIn("индекс изменился", result.stderr)


if __name__ == "__main__":
    unittest.main()
