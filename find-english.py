#!/usr/bin/env python3
"""Показывает английские строки, которые ещё видны игроку.

Ищет строковые литералы без кириллицы в вызовах вывода (SetText, AddLine,
AddDoubleLine, Print, print, ShowTextWindow) и в подписях настроек
(label/title/desc/help/sub). Технические имена и цветовые коды пропускает.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent / "addon"
DISPLAY = re.compile(r":(SetText|AddLine|AddDoubleLine|SetTitleText|ShowTextWindow)\(|ns:Print\(|(?<![\w.])print\(")
LABEL = re.compile(r"\b(label|title|desc|sub|help|suffix)\s*=\s*")
STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')
TECH = re.compile(
    r"^(Interface|Fonts|On[A-Z]|Set[A-Z]|[A-Z_]+$|number$|string$|table$|boolean$|check$|"
    r"choice$|slider$|money$|accent$|switch$|profile$|players?$|LEFT$|RIGHT$|CENTER$|"
    r"TOP$|BOTTOM$|BACKGROUND$|BORDER$|ARTWORK$|HIGHLIGHT$)"
)
CYR = re.compile(r"[\u0400-\u04FF]")


def literals(line: str):
    for m in STRING.finditer(line):
        yield m.group(1)


def main() -> int:
    found = 0
    for path in sorted(ROOT.glob("*.lua")):
        text = path.read_text(encoding="utf-8")
        for number, line in enumerate(text.splitlines(), 1):
            if line.lstrip().startswith("--"):
                continue
            if not (DISPLAY.search(line) or LABEL.search(line)):
                continue
            for value in literals(line):
                if CYR.search(value) or "\\" in value or "|c" in value:
                    continue
                words = re.findall(r"[A-Za-z]{3,}", value)
                if len(words) < 2 and not LABEL.search(line):
                    continue
                if TECH.match(value):
                    continue
                print(f"{path.name}:{number}: {line.strip()[:160]}")
                found += 1
                break
    print(f"\nКандидатов: {found}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
