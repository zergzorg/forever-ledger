#!/bin/zsh
set -euo pipefail

DEST="${1:-/Volumes/SSD_WD_BLUE/World of Warcraft/_forever_/Interface/AddOns/ForeverLedger}"

cd "$(dirname "$0")"

BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$BRANCH" != "ru" ]]; then
  echo "Текущая ветка: $BRANCH. Переключитесь на ru: git checkout ru"
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Есть незакоммиченные изменения. Сначала закоммитьте их."
  exit 1
fi

if [[ -d "$DEST" ]]; then
  mkdir -p "$HOME/Downloads"
  BACKUP="$HOME/Downloads/ForeverLedger-before-install-$(date +%Y%m%d-%H%M%S).tar.gz"
  tar czf "$BACKUP" -C "$(dirname "$DEST")" "$(basename "$DEST")"
  echo "Бэкап прежней версии: $BACKUP"
fi

LIST=$(mktemp)
{ awk 'NF && $0 !~ /^##/' ForeverLedger.toc
  echo ForeverLedger.toc; echo LICENSE; echo README.md; echo CHANGELOG.md; echo media
} > "$LIST"
rsync -a --delete --files-from="$LIST" . "$DEST"/
rm -f "$LIST"
echo "Установлено: $DEST"
echo "В игре: /reload (или полный перезапуск, если WoW был открыт во время установки)."
