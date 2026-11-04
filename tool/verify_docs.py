"""Offline checks for ordinary Markdown, without Flutter or Deno."""
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

from qa_scope import is_ordinary_doc


ROOT = Path(__file__).resolve().parents[1]
LINK = re.compile(r'\[[^\]\n]*\]\(\s*(?:<([^>\n]+)>|([^\s)]+))(?:\s+"[^"]*")?\s*\)')
CONFLICT = re.compile(r"^(?:<{7}|={7}|>{7})(?:\s|$)", re.MULTILINE)


def check_document(path, root):
    if path.is_symlink() or not path.is_file():
        return ["ожидается обычный Markdown-файл"]
    try:
        content = path.read_text(encoding="utf-8")
    except UnicodeError:
        return ["текст должен быть в UTF-8"]
    errors = []
    if CONFLICT.search(content):
        errors.append("найдены маркеры конфликта")
    # Examples in code blocks are not document links.
    prose = re.sub(r"(?ms)^```.*?^```[^\n]*|^~~~.*?^~~~[^\n]*", "", content)
    prose = re.sub(r"`[^`\n]+`", "", prose)
    for match in LINK.finditer(prose):
        target = match.group(1) or match.group(2)
        try:
            url = urlsplit(target)
            if url.scheme or url.netloc or not url.path:
                continue
            relative = unquote(url.path)
            destination = (root / relative.lstrip("/") if relative.startswith("/")
                           else path.parent / relative).resolve()
            destination.relative_to(root.resolve())
        except ValueError:
            errors.append(f"некорректная локальная ссылка: {target}")
            continue
        if not destination.exists():
            errors.append(f"не найден путь ссылки: {target}")
    return errors


def main():
    paths = [ROOT / "README.md", ROOT / "AGENTS.md"]
    paths.extend(path for path in sorted((ROOT / "docs").rglob("*.md"))
                 if is_ordinary_doc(path.relative_to(ROOT).as_posix()))
    errors = []
    for path in paths:
        errors.extend(f"{path.relative_to(ROOT)}: {error}" for error in check_document(path, ROOT))
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"Документация: {len(paths)} файлов, UTF-8, конфликты и локальные пути ссылок — OK.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
