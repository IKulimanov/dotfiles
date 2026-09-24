#!/usr/bin/env bash
# Quick Look для Markdown (QLMarkdown): пробел в Finder показывает
# отрендеренный .md вместо простыни текста.
#
#   ./macos/quicklook.sh          включить расширение и применить настройки из репозитория
#   ./macos/quicklook.sh --save   выгрузить текущие настройки приложения в репозиторий
#   ./macos/quicklook.sh --check  только проверить, ничего не менять
#
# Настройки QLMarkdown правятся в самом приложении (тема, шрифт, расширения
# Markdown). Приложение — в песочнице, поэтому его plist лежит в групповом
# контейнере, а не в ~/Library/Preferences. --save кладёт этот plist в
# macos/qlmarkdown.plist, обычный запуск возвращает его на место.
set -euo pipefail

APP="/Applications/QLMarkdown.app"
EXT_ID="org.sbarex.QLMarkdown.QLExtension"
GROUP="group.org.sbarex.qlmarkdown"
PREFS="$HOME/Library/Group Containers/$GROUP/Library/Preferences/$GROUP.plist"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_PLIST="$HERE/qlmarkdown.plist"

MODE="apply"
case "${1:-}" in
  --save)  MODE="save" ;;
  --check) MODE="check" ;;
  --help|-h) sed -n '2,8p' "$0"; exit 0 ;;
  "") ;;
  *) echo "Неизвестный аргумент: $1" >&2; exit 2 ;;
esac

if [[ ! -d "$APP" ]]; then
  echo "QLMarkdown не установлен: brew bundle --file=brew/Brewfile.apps" >&2
  exit 1
fi

# pluginkit печатает "+" для включённого расширения, "-" для выключенного
# и ничего, если система о нём ещё не знает.
ext_state() { pluginkit -m -i "$EXT_ID" 2>/dev/null | cut -c1; }

if [[ "$MODE" == "check" ]]; then
  case "$(ext_state)" in
    "+") echo "Quick Look для Markdown включён"; exit 0 ;;
    "-") echo "расширение QLMarkdown выключено: ./macos/quicklook.sh" >&2; exit 1 ;;
    *)   echo "расширение QLMarkdown не зарегистрировано: ./macos/quicklook.sh" >&2; exit 1 ;;
  esac
fi

if [[ "$MODE" == "save" ]]; then
  if [[ ! -f "$PREFS" ]]; then
    echo "Настройки ещё не созданы. Откройте QLMarkdown, поменяйте что-нибудь и повторите." >&2
    exit 1
  fi
  defaults export "$PREFS" "$REPO_PLIST"
  plutil -convert xml1 "$REPO_PLIST"   # xml вместо binary — чтобы был читаемый diff
  echo "Настройки сохранены: macos/qlmarkdown.plist"
  exit 0
fi

# ── Включение ────────────────────────────────────────────────────
# Система узнаёт о расширении только после первого запуска приложения.
if [[ -z "$(ext_state)" ]]; then
  echo "Регистрирую расширение (первый запуск QLMarkdown)…"
  open -g -j -a "$APP"
  for _ in $(seq 1 15); do
    [[ -n "$(ext_state)" ]] && break
    sleep 1
  done
  osascript -e 'tell application "QLMarkdown" to quit' 2>/dev/null || true
fi

pluginkit -e use -i "$EXT_ID" 2>/dev/null || true

if [[ -f "$REPO_PLIST" ]]; then
  mkdir -p "$(dirname "$PREFS")"
  cp "$REPO_PLIST" "$PREFS"
  # cfprefsd держит настройки в памяти и перезапишет файл своей копией
  killall -u "$USER" cfprefsd 2>/dev/null || true
  echo "Применены настройки из macos/qlmarkdown.plist"
fi

# Quick Look кеширует превью: без сброса старые .md останутся текстом
qlmanage -r >/dev/null 2>&1 || true
qlmanage -r cache >/dev/null 2>&1 || true

if [[ "$(ext_state)" == "+" ]]; then
  echo "Готово. Пробел на .md в Finder показывает отрендеренный Markdown."
else
  echo "Расширение не включилось. Включите вручную:" >&2
  echo "  Системные настройки → Основные → Login Items & Extensions → Quick Look" >&2
  exit 1
fi
