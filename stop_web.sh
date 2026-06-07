#!/usr/bin/env bash
# Останавливает все flutter run -d web-server для этого проекта.

set -euo pipefail

count=$(pgrep -fc 'run -d web-server' 2>/dev/null || true)
count=${count:-0}

if [[ "$count" -eq 0 ]]; then
  echo "Нет запущенных flutter web-server процессов."
  exit 0
fi

echo "Останавливаю $count процесс(ов) flutter web-server..."
pkill -f 'run -d web-server' || true
sleep 1

remaining=$(pgrep -fc 'run -d web-server' 2>/dev/null || true)
remaining=${remaining:-0}
if [[ "$remaining" -gt 0 ]]; then
  echo "Принудительная остановка..."
  pkill -9 -f 'run -d web-server' || true
fi

echo "Готово. Запуск снова: ./run_web.sh"
