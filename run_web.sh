#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if [[ ! -f dart_defines.json ]]; then
  echo "Файл dart_defines.json не найден."
  echo "Создайте его: cp dart_defines.example.json dart_defines.json"
  echo "и вставьте publishable key из Supabase Dashboard."
  exit 1
fi

if grep -q 'YOUR_PUBLISHABLE_KEY' dart_defines.json; then
  echo "В dart_defines.json всё ещё шаблон YOUR_PUBLISHABLE_KEY."
  echo "Вставьте настоящий ключ: Supabase Dashboard → Project Settings → API."
  exit 1
fi

echo "Запуск с ключами из dart_defines.json (нужен полный перезапуск после смены файла, не hot reload)."
exec flutter run -d web-server --dart-define-from-file=dart_defines.json "$@"
