#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s [all|answers|progress]\n' "$0"
}

if (( $# > 1 )); then
  usage >&2
  exit 64
fi

case "${1:-all}" in
  all) target=test ;;
  answers) target=test/answers ;;
  progress) target=test/progress ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 64 ;;
esac

cd "$(dirname "$0")/.."
# shellcheck source=toolchain.sh
source tool/toolchain.sh
check_started=$SECONDS

"$FLUTTER_BIN" pub get --enforce-lockfile
"$FLUTTER_BIN" analyze --no-pub
"$FLUTTER_BIN" test --no-pub --reporter expanded "$target"

printf '\nChecks passed (%s), %ss.\n' "${1:-all}" "$((SECONDS - check_started))"
