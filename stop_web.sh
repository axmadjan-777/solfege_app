#!/usr/bin/env bash
# Stop Flutter web-server only when its working directory is this checkout.
set -euo pipefail
project_dir=$(cd "$(dirname "$0")" && pwd -P)

if [[ ! -d /proc/self ]] && ! command -v lsof >/dev/null 2>&1; then
  echo "Нужен lsof для проверки каталога процесса; остановка отменена." >&2
  exit 1
fi

stopped=0
while IFS= read -r pid; do
  [[ -n "$pid" ]] || continue
  if [[ -d "/proc/$pid" ]]; then
    process_dir=$(readlink "/proc/$pid/cwd" 2>/dev/null || true)
  else
    process_dir=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' || true)
  fi
  if [[ "$process_dir" == "$project_dir" ]]; then
    if kill -TERM "$pid" 2>/dev/null; then
      echo "Отправлен SIGTERM Flutter web-server PID $pid в $project_dir."
      stopped=$((stopped + 1))
    fi
  fi
done < <(pgrep -f 'flutter_tools.snapshot.*run.*web-server' || true)

if [[ "$stopped" -eq 0 ]]; then
  echo "В этой рабочей копии не найден Flutter web-server."
fi
