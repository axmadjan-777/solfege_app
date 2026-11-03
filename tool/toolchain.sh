#!/usr/bin/env bash
# Source this file; it selects tools without installing or upgrading them.
# shellcheck source=tool/toolchain.env
source "$(dirname "${BASH_SOURCE[0]:-$0}")/toolchain.env"

SOLFEGE_TOOLCHAIN_DIR="${SOLFEGE_TOOLCHAIN_DIR:-${HOME}/.local/share/solfege_app/toolchains}"

if [[ -z "${FLUTTER_BIN:-}" ]]; then
  if [[ -x "$SOLFEGE_TOOLCHAIN_DIR/flutter-$FLUTTER_VERSION/bin/flutter" ]]; then
    FLUTTER_BIN="$SOLFEGE_TOOLCHAIN_DIR/flutter-$FLUTTER_VERSION/bin/flutter"
  elif command -v flutter >/dev/null 2>&1; then
    FLUTTER_BIN="$(command -v flutter)"
  else
    FLUTTER_BIN="${HOME}/flutter/bin/flutter"
  fi
fi

if [[ -z "${DENO_BIN:-}" ]]; then
  if [[ -x "$SOLFEGE_TOOLCHAIN_DIR/deno-$DENO_VERSION/deno" ]]; then
    DENO_BIN="$SOLFEGE_TOOLCHAIN_DIR/deno-$DENO_VERSION/deno"
  elif command -v deno >/dev/null 2>&1; then
    DENO_BIN="$(command -v deno)"
  else
    DENO_BIN="${HOME}/.deno/bin/deno"
  fi
fi

export FLUTTER_BIN DENO_BIN
