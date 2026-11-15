#!/usr/bin/env python3
"""English display text in the PR tree that the ruRU table doesn't cover and the
Russian build didn't keep as English either: real gaps to translate by hand."""
import re
import sys
from importlib import import_module
from pathlib import Path

sys.path.insert(0, "tools")
build = import_module("build-ru-locale")

text = Path("Locales/ruRU.lua").read_text(encoding="utf-8")
KEY = re.compile(r'^dictionary\["((?:[^"\\]|\\.)*)"\]', re.M)
keys = {k.replace('\\\\', '\\').replace('\\"', '"') for k in KEY.findall(text)}
diag = build.diagnostic_keys()

gaps = []
for name in sorted(p.name for p in Path(".").glob("*.lua")):
    if name in build.SKIP_FILES:
        continue
    ru_src = build.ru_lines(name)
    if ru_src is None:
        continue
    ru_lits = set()
    for line in ru_src:
        ru_lits.update(build.literals(line))
    for i, line in enumerate(Path(name).read_text(encoding="utf-8").splitlines(), 1):
        if line.lstrip().startswith("--"):
            continue
        for lit in build.literals(line):
            if lit in keys or lit in ru_lits or lit in diag:
                continue
            if not build.displayable(lit):
                continue
            gaps.append((name, i, lit))

print(f"{len(gaps)} строк", file=sys.stderr)
last = None
for name, line, lit in gaps:
    if name != last:
        print(f"\n## {name}")
        last = name
    print(f"{line}: {lit!r}")
