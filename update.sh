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
LIST=$(mktemp)
{ awk 'NF && $0 !~ /^##/' "$NEW/ForeverLedger.toc"
  echo ForeverLedger.toc; echo LICENSE; echo README.md; echo CHANGELOG.md
} > "$LIST"
rsync -a --files-from="$LIST" "$NEW"/ ./
rm -f "$LIST"
for f in *.lua; do
  grep -qx "$f" "$NEW/ForeverLedger.toc" || rm -f "$f"
done
rsync -a --delete "$NEW/media" ./
git add -A
if git diff --cached --quiet; then
  echo "Файлы совпадают с уже сохранённой версией upstream."
else
  git commit -qm "upstream $(date +%F)"
fi

VERSION=$(grep -m1 '^## Version:' ForeverLedger.toc | sed 's/.*: *//' || true)
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
