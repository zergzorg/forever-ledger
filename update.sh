#!/bin/zsh
set -euo pipefail

NEW="${1:-}"
if [[ -z "$NEW" || ! -f "$NEW/ForeverLedger.toc" ]]; then
  echo "Использование: ./update.sh /путь/к/новой/папке/ForeverLedger"
  echo "(в папке должен быть ForeverLedger.toc)"
  exit 1
fi

cd "$(dirname "$0")"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "В репозитории есть незакоммиченные изменения."
  echo "Закоммитьте их (git add -A && git commit) или уберите, затем повторите."
  exit 1
fi

git checkout -q upstream
rsync -a --delete "$NEW"/ addon/
git add -A addon
if git diff --cached --quiet; then
  echo "Файлы совпадают с уже сохранённой версией upstream."
else
  git commit -qm "upstream $(date +%F)"
fi

VERSION=$(grep -m1 '^## Version:' addon/ForeverLedger.toc | sed 's/.*: *//' || true)
git checkout -q ru

if git merge --no-edit upstream; then
  echo "Готово: перевод слит с версией ${VERSION:-?}."
  echo "Проверьте новые английские строки: python3 find-english.py"
  echo "Затем установите: ./install.sh"
else
  echo
  echo "Есть конфликты — их надо разобрать вручную:"
  git diff --name-only --diff-filter=U
  echo
  echo "1) откройте эти файлы и оставьте русский текст + изменения новой версии;"
  echo "2) git add -A && git commit;"
  echo "3) python3 find-english.py — untranslated new strings;"
  echo "4) ./install.sh"
  exit 2
fi
