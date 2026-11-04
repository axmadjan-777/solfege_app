#!/usr/bin/env bash
# Общий QA для рабочей копии, staged-снимка и CI. Без ключей живых сервисов.
set -euo pipefail

cd "$(dirname "$0")/.."

case "${1:-}" in
  --docs-only)
    [[ "$#" == 1 ]] || exit 2
    exec python3 tool/verify_docs.py
    ;;
  "")
    [[ "$#" == 0 ]] || exit 2
    ;;
  *)
    echo "Usage: bash tool/verify.sh [--docs-only]" >&2
    exit 2
    ;;
esac

python3 tool/verify_docs.py

# shellcheck source=tool/toolchain.sh
source tool/toolchain.sh
trap 'echo "QA остановлен с ошибкой на строке $LINENO." >&2' ERR

for executable in python3 npm "$FLUTTER_BIN" "$DENO_BIN"; do
  if ! command -v "$executable" >/dev/null 2>&1; then
    echo "Не найден $executable. Настройте SDK из tool/toolchain.env (см. README)." >&2
    exit 1
  fi
done

actual_flutter=$("$FLUTTER_BIN" --version --machine | python3 -c 'import json, sys; print(json.load(sys.stdin)["frameworkVersion"])')
actual_deno=$("$DENO_BIN" --version | awk '$1 == "deno" {print $2}')
if [[ "$actual_flutter" != "$FLUTTER_VERSION" || "$actual_deno" != "$DENO_VERSION" ]]; then
  echo "Нужны Flutter $FLUTTER_VERSION и Deno $DENO_VERSION; найдены $actual_flutter и $actual_deno." >&2
  echo "Выберите SDK через FLUTTER_BIN/DENO_BIN; харнесс не обновляет их автоматически." >&2
  exit 1
fi

echo "QA: Flutter $actual_flutter, Deno $actual_deno"
python3 -m unittest discover -s tool/tests -p 'test_*.py'
python3 -m unittest discover -s tool/browser/tests -p 'test_*.py'
"$FLUTTER_BIN" pub get --enforce-lockfile
"$FLUTTER_BIN" analyze --no-pub
python3 tool/extract_curriculum.py --check
"$FLUTTER_BIN" test --no-pub
"$DENO_BIN" check --no-lock supabase/functions/gemini-chat/index.ts tool/live/main.ts tool/tests/*.ts
"$DENO_BIN" test --no-check --no-lock --no-prompt tool/tests
npm ci --prefix tool/browser --ignore-scripts
node --test tool/browser/tests/sanitized_reporter.test.cjs
# The browser runner makes the one release build of the real app through its QA
# entry point, with fake client configuration. Chromium installation is explicit.
bash tool/verify_browser.sh
echo "Офлайн QA и браузерная приёмка пройдены. Живые сервисы проверяются отдельно."
