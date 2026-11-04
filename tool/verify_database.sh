#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tool/toolchain.env
actual_node=$(node --version)
if [[ "$actual_node" != "v$NODE_VERSION" ]]; then
  echo "Database QA requires Node $NODE_VERSION; found $actual_node." >&2
  exit 1
fi
npm ci --prefix tool/database --ignore-scripts --no-audit --no-fund
node tool/database/verify.mjs "$@"
