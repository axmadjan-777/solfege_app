#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

current_hooks=$(git config --get core.hooksPath || true)
if [[ -n "$current_hooks" && "$current_hooks" != .githooks ]]; then
  echo "Уже настроен core.hooksPath=$current_hooks; объедините существующие hooks вручную." >&2
  exit 1
fi
if [[ -z "$current_hooks" && -f "$(git rev-parse --git-path hooks/pre-commit)" ]]; then
  echo "Уже существует .git/hooks/pre-commit; сохраните его поведение перед установкой." >&2
  exit 1
fi

chmod +x .githooks/pre-commit
git config --local core.hooksPath .githooks
echo "Pre-commit QA подключён для этой рабочей копии. Ветки и коммиты не изменены."
