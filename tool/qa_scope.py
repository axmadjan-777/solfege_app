"""Classify a NUL-delimited Git diff; unknown or empty changes need full QA."""
from pathlib import PurePosixPath
import sys


def is_ordinary_doc(path):
    parts = PurePosixPath(path).parts
    if not parts or parts[-1] == "AGENTS.md":
        return False
    return path == "README.md" or (
        len(parts) > 1
        and parts[0] == "docs"
        and parts[1] != "curriculum"
        and path.endswith(".md")
        and ".." not in parts
    )


def classify(paths):
    return "docs" if paths and all(is_ordinary_doc(path) for path in paths) else "full"


if __name__ == "__main__":
    data = sys.stdin.buffer.read()
    # Do not accept a truncated or line-delimited file list as evidence to skip QA.
    try:
        paths = data[:-1].decode("utf-8").split("\0") if data.endswith(b"\0") else []
    except UnicodeDecodeError:
        paths = []
    print(classify(paths))
