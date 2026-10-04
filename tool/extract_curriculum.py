#!/usr/bin/env python3
"""Извлекает JSON-схемы и данные учебной программы из docs/curriculum/spec.md.

Каждый JSON-блок в спецификации предваряется строкой вида
    _Файл `data/levels.json`, 18 КБ, 319 строк. Приведён полностью._
за которой следует блок ```json ... ```.

Блоки `schemas/*.json` пишутся в docs/curriculum/schemas/, блоки `data/*.json` —
в assets/curriculum/. Файлы форматируются детерминированно (indent=2, ensure_ascii=False),
поэтому повторный запуск даёт побайтно идентичный результат.

Использование:
    python3 tool/extract_curriculum.py            # перезаписать файлы
    python3 tool/extract_curriculum.py --check    # сверить с закоммиченными, exit 1 при расхождении
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / "docs" / "curriculum" / "spec.md"
SCHEMAS_DIR = ROOT / "docs" / "curriculum" / "schemas"
DATA_DIR = ROOT / "assets" / "curriculum"

FILE_HEADER = re.compile(r"^_Файл `(?P<path>(?:schemas|data)/[\w.-]+\.json)`")

EXPECTED = {
    "schemas/lesson.schema.json",
    "schemas/competency.schema.json",
    "schemas/exercise.schema.json",
    "schemas/audio-item.schema.json",
    "data/levels.json",
    "data/source-map.json",
    "data/audio-manifest.json",
    "data/exercises.json",
    "data/competencies.json",
    "data/lessons.json",
}


def extract_blocks(lines: list[str]) -> dict[str, tuple[int, str]]:
    """Возвращает {путь_в_спеке: (номер_строки_начала, сырой_json)}."""
    blocks: dict[str, tuple[int, str]] = {}
    i = 0
    while i < len(lines):
        match = FILE_HEADER.match(lines[i])
        if not match:
            i += 1
            continue
        path = match.group("path")
        j = i + 1
        while j < len(lines) and lines[j].strip() == "":
            j += 1
        if j >= len(lines) or lines[j].strip() != "```json":
            raise SystemExit(f"{SPEC}:{i + 1}: после заголовка {path} нет блока ```json")
        start = j + 1
        end = start
        while end < len(lines) and lines[end].strip() != "```":
            end += 1
        if end >= len(lines):
            raise SystemExit(f"{SPEC}:{j + 1}: блок {path} не закрыт")
        if path in blocks:
            raise SystemExit(f"{SPEC}:{i + 1}: повторный блок {path}")
        blocks[path] = (start + 1, "\n".join(lines[start:end]))
        i = end + 1
    return blocks


def target_for(spec_path: str) -> Path:
    folder, name = spec_path.split("/", 1)
    return (SCHEMAS_DIR if folder == "schemas" else DATA_DIR) / name


def render(spec_path: str, line_no: int, raw: str) -> str:
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as e:
        raise SystemExit(
            f"{SPEC}:{line_no + e.lineno - 1}: {spec_path} не парсится как JSON: {e.msg}"
        )
    return json.dumps(parsed, ensure_ascii=False, indent=2) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--check",
        action="store_true",
        help="не писать файлы, а сверить с существующими (для CI)",
    )
    args = parser.parse_args()

    lines = SPEC.read_text(encoding="utf-8").splitlines()
    blocks = extract_blocks(lines)

    missing = EXPECTED - blocks.keys()
    extra = blocks.keys() - EXPECTED
    if missing or extra:
        print(f"Ожидаемые блоки не совпали: нет {sorted(missing)}, лишние {sorted(extra)}")
        return 1

    mismatches: list[str] = []
    for spec_path in sorted(blocks):
        line_no, raw = blocks[spec_path]
        content = render(spec_path, line_no, raw)
        target = target_for(spec_path)
        rel = target.relative_to(ROOT)
        if args.check:
            current = target.read_text(encoding="utf-8") if target.exists() else None
            if current != content:
                mismatches.append(str(rel))
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        print(f"{rel}  ← spec.md:{line_no}  ({len(content.encode('utf-8'))} байт)")

    if args.check:
        if mismatches:
            print("Извлечённые файлы расходятся со spec.md (запустите tool/extract_curriculum.py):")
            for m in mismatches:
                print(f"  {m}")
            return 1
        print(f"OK: {len(blocks)} JSON-блоков совпадают с docs/curriculum/spec.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
