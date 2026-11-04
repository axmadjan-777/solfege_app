#!/usr/bin/env bash
# Hosted-service acceptance is explicit and separate from offline verify.sh.
# Exit codes: 0 verified/preflight-only, 1 live failure/incomplete, 2 config/SDK,
# 3 artifact failure. Preflight status is never a live acceptance PASS.
set -euo pipefail

cd "$(dirname "$0")/.."

preflight=0
report_dir=build/qa-live
usage() {
  echo "Usage: bash tool/verify_live.sh [--preflight] [--report-dir PATH]"
}
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --preflight)
      [[ "$preflight" == 0 ]] || { usage >&2; exit 2; }
      preflight=1
      shift
      ;;
    --report-dir)
      [[ "$#" -ge 2 && -n "$2" && "$2" != -* ]] || { usage >&2; exit 2; }
      report_dir="$2"
      shift 2
      ;;
    --help|-h)
      usage
      echo "Requires QA_LIVE=1, QA_PROJECT_REF, QA_SUPABASE_URL, QA_SUPABASE_PUBLISHABLE_KEY,"
      echo "QA_USER_A_EMAIL/PASSWORD/ID and QA_USER_B_EMAIL/PASSWORD/ID. No SDK is installed."
      echo "Artifacts: summary.json, results.junit.xml, and (after a model response) gemini-evaluation.json."
      exit 0
      ;;
    *) usage >&2; exit 2 ;;
  esac
done

if ! mkdir -p -- "$report_dir"; then
  echo "Cannot create live QA artifact directory." >&2
  exit 3
fi
report_dir="$(cd -- "$report_dir" && pwd -P)"
mode=live
[[ "$preflight" == 0 ]] || mode=preflight

# shellcheck source=tool/toolchain.sh
source tool/toolchain.sh
export DENO_NO_UPDATE_CHECK=1

bootstrap_failure() {
  echo "$1" >&2
  if ! python3 tool/live/bootstrap_failure.py "$report_dir" "$mode" "$1"; then
    echo "Could not write live QA failure artifacts." >&2
    exit 3
  fi
  exit 2
}
if ! command -v "$DENO_BIN" >/dev/null 2>&1; then
  bootstrap_failure "Pinned Deno SDK is missing. Select the SDK from tool/toolchain.env through DENO_BIN; no live request was made."
fi
actual_deno="$("$DENO_BIN" --version 2>/dev/null | awk '$1 == "deno" {print $2}')" || bootstrap_failure "Deno SDK could not start; no live request was made."
if [[ "$actual_deno" != "$DENO_VERSION" ]]; then
  bootstrap_failure "Deno SDK does not match tool/toolchain.env; no live request was made."
fi

allowed_env=QA_LIVE,QA_PROJECT_REF,QA_SUPABASE_URL,QA_SUPABASE_PUBLISHABLE_KEY,QA_USER_A_EMAIL,QA_USER_A_PASSWORD,QA_USER_A_ID,QA_USER_B_EMAIL,QA_USER_B_PASSWORD,QA_USER_B_ID
deno_args=(run --check --no-lock --no-prompt "--allow-env=$allowed_env" "--allow-write=$report_dir")

# Configuration validation runs with networking denied, including in full mode.
"$DENO_BIN" "${deno_args[@]}" --deny-net tool/live/main.ts --preflight --report-dir "$report_dir"
if [[ "$preflight" == 1 ]]; then
  exit 0
fi

# QA_PROJECT_REF passed exact hosted-project validation above. The live process
# can connect only to this one host; redirects and all other hosts are rejected.
exec "$DENO_BIN" "${deno_args[@]}" "--allow-net=${QA_PROJECT_REF}.supabase.co:443" tool/live/main.ts --report-dir "$report_dir"
