"""Bind a reusable QA web bundle to its source inputs and pinned toolchain."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "build/browser-run.json"
BUNDLE = ROOT / "build/qa-web"


def digest(paths):
    result = hashlib.sha256()
    for path in sorted(paths):
        result.update(str(path.relative_to(ROOT)).encode())
        result.update(b"\0")
        result.update(path.read_bytes())
        result.update(b"\0")
    return result.hexdigest()


def inputs():
    paths = []
    for directory in ("lib", "assets", "web", "tool/browser/fonts"):
        paths.extend(path for path in (ROOT / directory).rglob("*") if path.is_file())
    paths.extend(ROOT / path for path in (
        "pubspec.yaml", "pubspec.lock", "test_driver/qa_main.dart",
        "tool/toolchain.env", "tool/browser/prepare_web.py",
    ))
    return digest(paths)


def source_tree():
    tree = os.environ.get("QA_SOURCE_TREE")
    if tree is None:
        tree = subprocess.check_output(
            ["git", "rev-parse", "HEAD^{tree}"], cwd=ROOT, text=True
        ).strip()
    if not re.fullmatch(r"[0-9a-f]{40,64}", tree):
        raise SystemExit("QA_SOURCE_TREE must be an exact Git tree hash")
    return tree


def bundle_digest():
    if not (BUNDLE / "main.dart.js").is_file():
        raise SystemExit("QA bundle missing; run the browser build first")
    return digest(path for path in BUNDLE.rglob("*") if path.is_file())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("operation", choices=("source-tree", "inputs", "create", "check"))
    parser.add_argument("--flutter")
    parser.add_argument("--optimization-level", type=int, choices=(1, 4), default=4)
    parser.add_argument("--expected-inputs")
    args = parser.parse_args()
    if args.operation == "source-tree":
        print(source_tree())
        return
    fingerprint = inputs()
    if args.operation == "inputs":
        print(fingerprint)
        return
    if args.operation == "create":
        if fingerprint != args.expected_inputs:
            raise SystemExit("App inputs changed during compilation; rebuild a stable source tree")
        data = {
            "flutter": args.flutter,
            "optimization_level": args.optimization_level,
            "source_tree": source_tree(),
            "source_inputs_sha256": fingerprint,
            "bundle_sha256": bundle_digest(),
            "target": "test_driver/qa_main.dart",
            "backend": "https://qa.invalid",
        }
        MANIFEST.write_text(json.dumps(data, indent=2) + "\n")
        return
    if not MANIFEST.is_file():
        raise SystemExit("QA bundle manifest missing; rebuild the QA target")
    data = json.loads(MANIFEST.read_text())
    expected = {
        "flutter": args.flutter,
        "optimization_level": args.optimization_level,
        "source_tree": source_tree(),
        "source_inputs_sha256": fingerprint,
        "bundle_sha256": bundle_digest(),
        "target": "test_driver/qa_main.dart",
        "backend": "https://qa.invalid",
    }
    mismatched = [key for key, value in expected.items() if data.get(key) != value]
    if mismatched:
        raise SystemExit("QA bundle does not match current source/config: " + ", ".join(mismatched))
    print("PASS: QA bundle matches source, toolchain, optimization and recorded bytes")


if __name__ == "__main__":
    main()
