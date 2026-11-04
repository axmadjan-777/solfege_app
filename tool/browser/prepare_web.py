"""Host the SDK's pinned default font locally in the generated QA build only."""

import argparse
import hashlib
from pathlib import Path
import re
import shutil


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    source = Path(__file__).parent / "fonts"
    for entry in (source / "SHA256SUMS").read_text().splitlines():
        digest, relative = entry.split(maxsplit=1)
        actual = hashlib.sha256((source / relative).read_bytes()).hexdigest()
        if actual != digest:
            raise SystemExit(f"Pinned font checksum mismatch: {relative}")
    shutil.copytree(source, args.directory / "qa-fonts", dirs_exist_ok=True)
    bootstrap = args.directory / "flutter_bootstrap.js"
    updated, count = re.subn(
        r"_flutter\.loader\.load\(\{\s*serviceWorkerSettings:",
        '_flutter.loader.load({\n  config: {fontFallbackBaseUrl: "/qa-fonts/"},\n  serviceWorkerSettings:',
        bootstrap.read_text(),
    )
    if count != 1:
        raise SystemExit("Expected one default Flutter loader call; QA font configuration was not applied")
    bootstrap.write_text(updated)


if __name__ == "__main__":
    main()
