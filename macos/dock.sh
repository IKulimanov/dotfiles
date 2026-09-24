#!/usr/bin/env bash
# Шпаргалка по nvim в Dock: значок, по клику открывается docs/nvim-cheatsheet.html.
#
#   ./macos/dock.sh           собрать значок и закрепить его в Dock
#   ./macos/dock.sh --check   только проверить, ничего не менять
#
# Сам .html в Dock тоже закрепляется, но с иконкой браузера и только справа,
# у Корзины. Поэтому собирается ярлык ~/Applications/Шпаргалка nvim.app —
# апплет AppleScript со своей иконкой, место ему среди приложений.
# Путь к странице записан в ярлыке: переехал репозиторий — запустить снова.
# Убрать: вытащить значок из Dock и удалить ярлык.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PAGE="$(dirname "$HERE")/docs/nvim-cheatsheet.html"
APP="$HOME/Applications/Шпаргалка nvim.app"
# По нему скрипт узнаёт свой ярлык и не трогает чужое приложение с тем же именем
BUNDLE_ID="local.dotfiles.nvim-cheatsheet"

MODE="apply"
case "${1:-}" in
  --check) MODE="check" ;;
  --help|-h) sed -n '2,11p' "$0"; exit 0 ;;
  "") ;;
  *) echo "Неизвестный аргумент: $1" >&2; exit 2 ;;
esac

# Адрес ярлыка в том виде, в каком его хранит Dock: file:// с %-кодированием кириллицы
app_url() {
  osascript -l JavaScript \
    -e 'function run(argv) { ObjC.import("Foundation"); return $.NSURL.fileURLWithPathIsDirectory(argv[0], true).absoluteString.js }' \
    "$APP"
}

in_dock() {
  defaults read com.apple.dock persistent-apps 2>/dev/null | grep -qF "$(app_url)"
}

if [[ "$MODE" == "check" ]]; then
  if [[ ! -d "$APP" ]]; then
    echo "значка шпаргалки нет: make dock" >&2
    exit 1
  fi
  if in_dock; then
    echo "Шпаргалка по nvim закреплена в Dock"
    exit 0
  fi
  echo "значок собран, но не закреплён в Dock: make dock" >&2
  exit 1
fi

if [[ ! -f "$PAGE" ]]; then
  echo "Нет страницы ${PAGE}" >&2
  exit 1
fi

# ── Ярлык ────────────────────────────────────────────────────────
# Собираем заново при каждом запуске: так в нём всегда актуальные путь и иконка.
if [[ -d "$APP" ]]; then
  if [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist" 2>/dev/null)" != "$BUNDLE_ID" ]]; then
    echo "${APP} — чужое приложение, не трогаю. Переименуйте его и запустите снова." >&2
    exit 1
  fi
  rm -rf "$APP"
fi
mkdir -p "$(dirname "$APP")"

# Путь уходит в строку AppleScript: экранируем \ и "
page_as="${PAGE//\\/\\\\}"
page_as="${page_as//\"/\\\"}"
# osacompile сам подписывает апплет и пишет об этом строку — показываем вывод только при ошибке
if ! out="$(osacompile -o "$APP" -e "do shell script \"open \" & quoted form of \"${page_as}\"" 2>&1)"; then
  echo "$out" >&2
  exit 1
fi
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$APP/Contents/Info.plist"

# ── Иконка ───────────────────────────────────────────────────────
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
if osascript -l JavaScript "$HERE/dock-icon.js" "$tmp/icon.png" >/dev/null; then
  mkdir "$tmp/icon.iconset"
  for s in 16 32 128 256 512; do
    sips -z "$s" "$s" "$tmp/icon.png" --out "$tmp/icon.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$tmp/icon.png" --out "$tmp/icon.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$tmp/icon.iconset" -o "$APP/Contents/Resources/applet.icns"
else
  echo "Иконку нарисовать не вышло, останется стандартная" >&2
fi

# Info.plist и иконка поменялись, подпись апплета больше не сходится — подписываем заново
if ! codesign --force --sign - "$APP" 2>/dev/null; then
  echo "Не удалось переподписать ярлык: если он не откроется, запустите make dock ещё раз" >&2
fi
# Finder и Dock кешируют иконки: сообщаем системе, что приложение обновилось
touch "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" 2>/dev/null || true

# ── Dock ─────────────────────────────────────────────────────────
if in_dock; then
  killall Dock
  echo "Значок обновлён, он уже был в Dock."
else
  defaults write com.apple.dock persistent-apps -array-add \
    "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$(app_url)</string><key>_CFURLStringType</key><integer>15</integer></dict></dict><key>tile-type</key><string>file-tile</string></dict>"
  killall Dock
  echo "Готово: «Шпаргалка nvim» в Dock, последней среди приложений."
fi
