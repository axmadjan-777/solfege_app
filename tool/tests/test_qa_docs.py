"""Guard the boundary between ordinary prose and executable project inputs."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
from qa_scope import classify
from verify_docs import check_document


class DocumentationQATest(unittest.TestCase):
    def test_only_ordinary_docs_can_skip_full_qa(self):
        ordinary = ["README.md", "docs/architecture.md", "docs/new note.md"]
        self.assertEqual(classify(ordinary), "docs")
        for protected in (
            "docs/curriculum/spec.md", "docs/curriculum/README.md",
            "docs/curriculum/schemas/lesson.schema.json", "assets/curriculum/lessons.json",
            "lib/main.dart", "test/widget_test.dart", "supabase/schema.sql",
            "tool/verify.sh", ".github/workflows/verify.yml", ".githooks/pre-commit",
            "AGENTS.md", "docs/AGENTS.md", "pubspec.lock", "unknown.md",
        ):
            with self.subTest(path=protected):
                self.assertEqual(classify(ordinary + [protected]), "full")

    def test_missing_or_malformed_change_list_falls_back_to_full_qa(self):
        for data in (b"", b"README.md\n", b"README.md\0\xff\0", b"README.md\0\0"):
            with self.subTest(data=data):
                result = subprocess.run(
                    [sys.executable, str(ROOT / "tool/qa_scope.py")],
                    input=data, capture_output=True, check=True,
                )
                self.assertEqual(result.stdout.strip(), b"full")
        result = subprocess.run(
            [sys.executable, str(ROOT / "tool/qa_scope.py")],
            input=b"README.md\0docs/with\nnewline.md\0", capture_output=True, check=True,
        )
        self.assertEqual(result.stdout.strip(), b"docs")

    def test_document_links_are_checked_offline(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            document = root / "README.md"
            (root / "file with spaces.md").write_text("# Target\n")
            document.write_text(
                '[ok](file%20with%20spaces.md#heading) [anchor](#heading)\n'
                '[remote](https://example.invalid/unavailable)\n'
                '```md\n[example](does-not-exist.md)\n```\n'
            )
            self.assertEqual(check_document(document, root), [])
            document.write_text('[missing](does-not-exist.md)\n')
            self.assertTrue(check_document(document, root))
            document.write_text('[outside](../outside.md)\n')
            self.assertTrue(check_document(document, root))

    def test_invalid_text_conflicts_and_symlinks_fail_light_qa(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            document = root / "README.md"
            document.write_bytes(b"\xff")
            self.assertTrue(check_document(document, root))
            document.write_text("<<<<<<< HEAD\nours\n=======\ntheirs\n>>>>>>> other\n")
            self.assertTrue(check_document(document, root))
            target = root / "target.md"
            document.rename(target)
            document.symlink_to(target)
            self.assertTrue(check_document(document, root))


if __name__ == "__main__":
    unittest.main()
