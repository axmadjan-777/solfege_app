#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck source=tool/toolchain.sh
source tool/toolchain.sh

usage() {
  cat <<'EOF'
Usage: bash tool/verify_browser.sh [--update-snapshots] [--project=NAME]
                                 [--optimization-level=1|4] [--reuse-build] [--live]

Default: build real release O4 QA target, serve loopback, compare offline
Playwright screenshots. Explicit setup before first use:
  npm --prefix tool/browser ci --ignore-scripts
  (cd tool/browser && npx playwright install chromium)

--update-snapshots       Deliberately replace offline baselines; review PNGs.
--project=NAME           chromium-mobile or chromium-desktop (default: both).
--optimization-level=1   Explicit faster local iteration; acceptance defaults to 4.
--reuse-build            Verify existing QA bundle/source manifest; no Flutter calls.
--live                   Separate live UI suite with sanitized results only.
QA_BROWSER_PORT          Optional loopback port (default: 8765).
QA_SOURCE_TREE           Exact source Git tree (required in snapshots without .git).
EOF
}

MODE=offline
REUSE_BUILD=false
OPTIMIZATION_LEVEL=4
PROJECT=''
UPDATE_SNAPSHOTS=false
for arg in "$@"; do
  case "$arg" in
    --update-snapshots) UPDATE_SNAPSHOTS=true ;;
    --project=chromium-mobile|--project=chromium-desktop) PROJECT="$arg" ;;
    --optimization-level=1|--optimization-level=4) OPTIMIZATION_LEVEL="${arg#*=}" ;;
    --reuse-build) REUSE_BUILD=true ;;
    --live) MODE=live ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
if [[ "$MODE" == live && ( "$UPDATE_SNAPSHOTS" == true || -n "$PROJECT" ) ]]; then
  printf '%s\n' 'Live checks use their own project and never record screenshot baselines.' >&2
  exit 2
fi
if [[ ! -x tool/browser/node_modules/.bin/playwright ]]; then
  printf '%s\n' 'Missing pinned browser dependencies. Run: npm --prefix tool/browser ci --ignore-scripts' >&2
  exit 1
fi
npm --prefix tool/browser run typecheck
(cd tool/browser && node - <<'JS'
const { chromium } = require('@playwright/test');
const fs = require('node:fs');
if (!fs.existsSync(chromium.executablePath())) {
  console.error('Pinned Chromium missing. Run: (cd tool/browser && npx playwright install chromium)');
  process.exit(1);
}
JS
)

PORT="${QA_BROWSER_PORT:-8765}"
if [[ ! "$PORT" =~ ^[1-9][0-9]*$ || "$PORT" -lt 1024 || "$PORT" -gt 65535 ]]; then
  printf '%s\n' 'QA_BROWSER_PORT must be an integer in 1024..65535.' >&2
  exit 2
fi
SOURCE_TREE="$(python3 tool/browser/bundle_manifest.py source-tree)"
export QA_SOURCE_TREE="$SOURCE_TREE"
mkdir -p build
SERVER_PID=''
SERVER_READY_FILE=''
cleanup() {
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
    rm -f "$SERVER_READY_FILE"
  fi
  if [[ "$MODE" == live ]]; then
    # Playwright can write error-context.md even with tracing disabled.
    rm -rf build/browser-live-private
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ "$REUSE_BUILD" == true ]]; then
  python3 tool/browser/bundle_manifest.py check --flutter "$FLUTTER_VERSION" \
    "--optimization-level=$OPTIMIZATION_LEVEL"
else
  if [[ ! -x "$FLUTTER_BIN" ]]; then
    printf '%s\n' "Flutter missing: $FLUTTER_BIN (see tool/toolchain.sh)" >&2
    exit 1
  fi
  ACTUAL_FLUTTER_VERSION="$("$FLUTTER_BIN" --version --machine | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])')"
  if [[ "$ACTUAL_FLUTTER_VERSION" != "$FLUTTER_VERSION" ]]; then
    printf '%s\n' "Flutter $FLUTTER_VERSION required; found $ACTUAL_FLUTTER_VERSION. SDK was not changed." >&2
    exit 1
  fi
  BUILD_INPUTS="$(python3 tool/browser/bundle_manifest.py inputs)"
  "$FLUTTER_BIN" pub get --enforce-lockfile
  "$FLUTTER_BIN" build web --release --no-pub --no-wasm-dry-run \
    "--optimization-level=$OPTIMIZATION_LEVEL" \
    --target=test_driver/qa_main.dart --output=build/qa-web \
    --base-href=/ --no-web-resources-cdn \
    --dart-define=SUPABASE_URL=https://qa.invalid \
    --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_qa_fixture \
    "--dart-define=AUTH_REDIRECT_URL=http://127.0.0.1:$PORT/"
  python3 tool/browser/prepare_web.py build/qa-web
  python3 tool/browser/bundle_manifest.py create --flutter "$ACTUAL_FLUTTER_VERSION" \
    "--optimization-level=$OPTIMIZATION_LEVEL" "--expected-inputs=$BUILD_INPUTS"
fi

SERVER_READY_FILE="$(mktemp "$ROOT/build/browser-server.XXXXXX")"
python3 tool/browser/serve_web.py build/qa-web --port "$PORT" \
  --ready-file "$SERVER_READY_FILE" >build/browser-server.log 2>&1 &
SERVER_PID=$!
python3 - "$SERVER_PID" "$PORT" "$SERVER_READY_FILE" <<'PY'
import os
from pathlib import Path
import sys
import time
import urllib.request

pid, port = map(int, sys.argv[1:3])
ready = Path(sys.argv[3])
for _ in range(300):
    time.sleep(0.1)
    os.kill(pid, 0)
    if not ready.exists() or ready.read_text().strip() != str(pid):
        continue
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/", timeout=1) as response:
            if response.status == 200:
                break
    except OSError:
        continue
else:
    raise SystemExit("QA server did not become ready; see build/browser-server.log")
PY

# Keep arrays nonempty for macOS Bash 3.2 with set -u.
PLAYWRIGHT_ARGS=(--config=playwright.config.ts)
if [[ "$MODE" == live ]]; then
  PLAYWRIGHT_ARGS=(--config=playwright.live.config.ts)
else
  if [[ "$UPDATE_SNAPSHOTS" == true ]]; then PLAYWRIGHT_ARGS+=(--update-snapshots=all); fi
  if [[ -n "$PROJECT" ]]; then PLAYWRIGHT_ARGS+=("$PROJECT"); fi
fi
if [[ "$MODE" == live ]]; then
  # Suppress protocol/Node debug logging that could expose auth headers or input.
  DEBUG= PWDEBUG= NODE_DEBUG= \
    QA_BROWSER_BASE_URL="http://127.0.0.1:$PORT" \
    QA_BROWSER_OPTIMIZATION_LEVEL="$OPTIMIZATION_LEVEL" \
    npm --prefix tool/browser test -- "${PLAYWRIGHT_ARGS[@]}"
else
  QA_BROWSER_BASE_URL="http://127.0.0.1:$PORT" \
    QA_BROWSER_OPTIMIZATION_LEVEL="$OPTIMIZATION_LEVEL" \
    npm --prefix tool/browser test -- "${PLAYWRIGHT_ARGS[@]}"
fi
