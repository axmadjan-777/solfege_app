#!/usr/bin/env python3
"""Write a credential-free failure artifact when the pinned SDK cannot start."""

import datetime
import html
import json
from pathlib import Path
import sys
import uuid


def main() -> None:
    directory = Path(sys.argv[1])
    mode = sys.argv[2]
    # The caller supplies only static text, never SDK output or configuration.
    detail = sys.argv[3]
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    check = {
        "id": "bootstrap",
        "name": "Pinned Deno prerequisite",
        "status": "failed",
        "durationMs": 0,
        "detail": detail,
    }
    report = {
        "schemaVersion": 1,
        "suite": "solfege-hosted-services",
        "runId": str(uuid.uuid4()),
        "startedAt": now,
        "finishedAt": now,
        "mode": mode,
        "status": "configuration_error",
        "exitCode": 2,
        "liveAcceptance": "not_run",
        "checks": [check],
        "cleanup": [],
        "limitations": ["Live services were not contacted because the pinned SDK could not start."],
    }
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    (directory / "gemini-evaluation.json").unlink(missing_ok=True)
    (directory / "summary.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )
    (directory / "results.junit.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<testsuites><testsuite name="solfege-hosted-services-bootstrap" tests="1" '
        'failures="1" skipped="0"><testcase name="bootstrap">'
        f'<failure type="configuration_error" message="{html.escape(detail, quote=True)}"/>'
        '</testcase></testsuite></testsuites>\n',
        encoding="utf-8",
    )
    for filename in ("summary.json", "results.junit.xml"):
        (directory / filename).chmod(0o600)


if __name__ == "__main__":
    main()
