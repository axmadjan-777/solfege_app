#!/usr/bin/env bash
# Полная проверка ветки: зависимости, анализатор, сверка JSON со спецификацией, тесты.
set -euo pipefail

cd "$(dirname "$0")/.."

if command -v flutter >/dev/null 2>&1; then
  FLUTTER=flutter
elif [[ -x "${HOME}/flutter/bin/flutter" ]]; then
  FLUTTER="${HOME}/flutter/bin/flutter"
else
  echo "flutter не найден ни в PATH, ни в \$HOME/flutter" >&2
  exit 1
fi

"$FLUTTER" pub get
"$FLUTTER" analyze
python3 tool/extract_curriculum.py --check
"$FLUTTER" test
