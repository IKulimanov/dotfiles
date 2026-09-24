#!/usr/bin/env bash
# Установщик dotfiles. Безопасно перезапускается: каждый шаг проверяет,
# не сделан ли он уже, и спрашивает подтверждение.
#
#   ./install.sh              обычный интерактивный запуск
#   ./install.sh --check      только проверить, что установлено, ничего не менять
#   ./install.sh --dry-run    показать, что будет сделано, ничего не меняя
#   ./install.sh --yes        не задавать вопросов (для новой машины)
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
PACKAGES=(zsh git nvim lazygit tig k9s sec)
ZSH_DIR="$XDG_CONFIG/zsh/oh-my-zsh"
IDENTITY="$XDG_CONFIG/git/identity"
# .DS_Store не должен становиться симлинком, даже если Finder его создал
STOW_OPTS=(--no-folding --ignore='\.DS_Store')

ASSUME_YES=0
DRY_RUN=0
CHECK_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y)     ASSUME_YES=1 ;;
    --dry-run|-n) DRY_RUN=1 ;;
    --check|-c)   CHECK_ONLY=1 ;;
    --help|-h)    sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "Неизвестный аргумент: $arg" >&2; exit 2 ;;
  esac
done

# ── Вывод ──────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
  RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; BLUE=''; RED=''; BOLD=''; NC=''
fi
info()   { printf "${BLUE}▸${NC} %s\n" "$*"; }
ok()     { printf "${GREEN}✓${NC} %s\n" "$*"; }
warn()   { printf "${YELLOW}!${NC} %s\n" "$*"; }
err()    { printf "${RED}✗${NC} %s\n" "$*" >&2; }
header() { printf "\n${BOLD}═══ %s ═══${NC}\n\n" "$*"; }
run()    { if (( DRY_RUN )); then printf "  ${YELLOW}[dry-run]${NC} %s\n" "$*"; else eval "$*"; fi; }

# ── Ввод ───────────────────────────────────────────────────────
# Читаем из /dev/tty, а не из stdin: скрипт может быть запущен
# через пайп, и тогда обычный read проглотил бы его же текст.
ask() {
  (( ASSUME_YES )) && return 0
  (( DRY_RUN ))    && return 1
  [[ -e /dev/tty ]] || return 1
  local answer
  printf "${BOLD}%s${NC} [y/N] " "$1" > /dev/tty
  IFS= read -r answer < /dev/tty || return 1
  [[ "$answer" =~ ^[Yy]$ ]]
}

askval() {
  local prompt="$1" default="${2:-}" answer
  if [[ ! -e /dev/tty ]] || (( DRY_RUN )); then printf '%s' "$default"; return; fi
  if [[ -n "$default" ]]; then
    printf "${BOLD}%s${NC} [%s]: " "$prompt" "$default" > /dev/tty
  else
    printf "${BOLD}%s${NC}: " "$prompt" > /dev/tty
  fi
  IFS= read -r answer < /dev/tty || answer=""
  printf '%s' "${answer:-$default}"
}

# Спрашивает, пока не получит непустой ответ.
# ВАЖНО: результат забирают через $(askreq …), поэтому в stdout не должно
# попасть ничего, кроме самого значения. Приглашения и предупреждения —
# только в /dev/tty, иначе их текст окажется в имени или почте.
askreq() {
  local v=""
  while [[ -z "$v" ]]; do
    v="$(askval "$1" "${2:-}")"
    [[ -n "$v" ]] && break
    # Спрашивать бесконечно можно только там, где есть кому отвечать.
    # В --dry-run и без терминала askval сразу возвращает пустое значение,
    # и цикл крутился бы вечно.
    if (( DRY_RUN )) || [[ ! -e /dev/tty ]]; then break; fi
    warn "Значение обязательно." > /dev/tty
  done
  printf '%s' "$v"
}

# Значение для конфига git: одна строка, без управляющих символов.
# Многострочное значение даёт «fatal: bad config line N» на каждой команде git.
oneline() { printf '%s' "$1" | tr -d '\r\n\033' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }

# Файл считается «нашим», если это симлинк внутрь каталога dotfiles.
# stow пишет относительные ссылки (dotfiles/zsh/.zshenv, ../../dotfiles/…),
# поэтому сравниваем не текст ссылки, а разрешённый путь.
is_ours() {
  [[ -L "$1" ]] || return 1
  local link target; link="$(readlink "$1")"
  [[ "$link" == /* ]] || link="$(dirname "$1")/$link"
  target="$(cd "$(dirname "$link")" 2>/dev/null && pwd -P)/$(basename "$link")"
  [[ "$target" == "$DOTFILES"/* ]]
}

# ═══════════════════════════════════════════════════════════════
#  Проверка: что установлено, что подключено, чего не хватает.
#  Запускается в конце установки и отдельно: ./install.sh --check
# ═══════════════════════════════════════════════════════════════
check_all() {
  local fails=0
  pass() { ok "$1"; }
  fail() { err "$1"; [[ -n "${2:-}" ]] && printf "      ${YELLOW}→${NC} %s\n" "$2"; fails=$((fails + 1)); }

  header "Проверка"

  # инструменты
  local t
  for t in brew stow git nvim delta lazygit tig fzf fd bat eza zoxide age; do
    if command -v "$t" &>/dev/null; then pass "$t"; else fail "$t не найден" "make core"; fi
  done
  if command -v git &>/dev/null && [[ "$(command -v git)" == /usr/bin/git ]]; then
    warn "git — системный ($(git --version | awk '{print $3}')); brew-версия встанет впереди после exec zsh"
  fi
  if compgen -G "$HOME/Library/Fonts/MesloLGSNerdFont*" >/dev/null || compgen -G "/Library/Fonts/MesloLGSNerdFont*" >/dev/null; then
    pass "шрифт MesloLGS Nerd Font"
  else
    fail "шрифт MesloLGS Nerd Font не установлен" "make core, затем выбрать его в iTerm2"
  fi

  # симлинки
  local pkg rel missing
  for pkg in "${PACKAGES[@]}"; do
    missing=""
    while IFS= read -r rel; do
      is_ours "$HOME/$rel" || missing="$missing $rel"
    done < <(cd "$DOTFILES/$pkg" && find . \( -type f -o -type l \) ! -name .DS_Store | sed 's|^\./||')
    if [[ -z "$missing" ]]; then pass "пакет $pkg подключён"; else fail "пакет $pkg: не подключено:$missing" "make relink"; fi
  done

  # zsh
  check_dir() {   # каталог, название, что делать если нет
    if [[ -d "$1" ]]; then pass "$2"; else fail "$2: не установлен" "${3:-./install.sh → шаг Zsh}"; fi
  }
  check_dir "$ZSH_DIR"                                       "oh-my-zsh"
  check_dir "$ZSH_DIR/custom/themes/powerlevel10k"           "тема powerlevel10k"
  check_dir "$ZSH_DIR/custom/plugins/zsh-autosuggestions"    "zsh-autosuggestions"
  check_dir "$ZSH_DIR/custom/plugins/zsh-syntax-highlighting" "zsh-syntax-highlighting"
  check_dir "$ZSH_DIR/custom/plugins/forgit"                 "forgit"
  if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]] && grep -q 'Path to your Oh My Zsh installation' "$HOME/.zshrc" 2>/dev/null; then
    # shellcheck disable=SC2088  # ~ здесь просто текст сообщения, не путь
    fail "~/.zshrc — шаблон от установщика Oh-My-Zsh, он не используется (ZDOTDIR=~/.config/zsh)" "./install.sh уберёт его в бэкап"
  fi
  if [[ "$SHELL" == */zsh ]]; then
    pass "шелл по умолчанию: zsh"
  else
    fail "шелл по умолчанию: $SHELL" "chsh -s \$(which zsh)"
  fi

  # git
  if [[ ! -f "$IDENTITY" ]]; then
    fail "git identity не настроена — коммиты подпишутся именем машины" "make identity"
  elif ! git config -f "$IDENTITY" --list >/dev/null 2>&1; then
    fail "git identity не читается: $(git config -f "$IDENTITY" --list 2>&1 | head -1)" "make identity"
  else
    pass "git identity: $(git config -f "$IDENTITY" user.name) <$(git config -f "$IDENTITY" user.email)>"
  fi

  # Quick Look для Markdown — не обязателен, поэтому предупреждение, а не ошибка
  if [[ -d /Applications/QLMarkdown.app ]]; then
    if [[ "$(pluginkit -m -i org.sbarex.QLMarkdown.QLExtension 2>/dev/null | cut -c1)" == "+" ]]; then
      pass "Quick Look для Markdown"
    else
      warn "QLMarkdown установлен, но расширение выключено — make quicklook"
    fi
  fi

  echo ""
  if (( fails == 0 )); then
    ok "Всё на месте."
  else
    warn "Проблем: $fails. Команды для исправления — справа от каждой."
  fi
  return 0
}

if (( CHECK_ONLY )); then check_all; exit 0; fi

# ═══════════════════════════════════════════════════════════════
#  1. Homebrew
# ═══════════════════════════════════════════════════════════════
header "Homebrew"

if ! command -v brew &>/dev/null; then
  if ask "Установить Homebrew? (менеджер пакетов для macOS)"; then
    # shellcheck disable=SC2016  # подстановка выполняется внутри run, а не здесь
    run '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  fi
fi

# Установщик Homebrew не добавляет brew в PATH текущего процесса.
# Без этого шага все последующие проверки command -v brew провалятся,
# и пакеты не поставятся — молча.
if ! command -v brew &>/dev/null; then
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$candidate" ]]; then eval "$("$candidate" shellenv)"; break; fi
  done
fi

if command -v brew &>/dev/null; then
  ok "Homebrew: $(brew --version | head -1)"
else
  warn "Homebrew недоступен — шаг с пакетами будет пропущен"
fi

# ═══════════════════════════════════════════════════════════════
#  2. Пакеты
# ═══════════════════════════════════════════════════════════════
if command -v brew &>/dev/null; then
  header "Пакеты"

  bundle() {
    local file="$1" title="$2" desc="$3"
    echo "  $desc"
    echo ""
    if ask "Установить: $title?"; then
      # Не прерываем установку целиком, если один пакет не встал
      # (например, переименовался токен cask).
      if run "brew bundle --file='$DOTFILES/$file'"; then
        ok "$title"
      else
        warn "$title: часть пакетов не установилась, см. вывод выше"
      fi
    fi
  }

  bundle brew/Brewfile.core "базовый набор" \
    "CLI-инструменты, на которые опирается конфиг: stow, шрифт MesloLGS Nerd Font,
  git, bat, eza, fd, ripgrep, fzf, zoxide, jq, trash, neovim, gh, delta,
  lazygit, tig, direnv, mise. Шрифт обязателен — без него промпт рисует квадраты."

  echo ""
  bundle brew/Brewfile.apps "GUI-приложения" \
    "iTerm2, Docker, Raycast, Espanso, Hidden Bar, AppCleaner, Keka,
  IINA, Obsidian."
fi

# ═══════════════════════════════════════════════════════════════
#  3. Линковка конфигов (stow)
# ═══════════════════════════════════════════════════════════════
header "Конфиги (GNU Stow)"

if ! command -v stow &>/dev/null; then
  warn "stow не установлен — конфиги не подключены."
  warn "Установите (brew install stow) и запустите скрипт снова."
else
  backup_conflicts() {
    local pkg="$1" rel target stamp dest found=0
    stamp="$(date +%Y%m%d-%H%M%S)"
    while IFS= read -r rel; do
      target="$HOME/$rel"
      [[ -e "$target" || -L "$target" ]] || continue
      is_ours "$target" && continue
      if (( found == 0 )); then
        warn "В \$HOME уже есть файлы из пакета «${pkg}» — переношу в бэкап:"
        found=1
      fi
      dest="$HOME/.dotfiles-backup/$stamp/$rel"
      echo "    $rel"
      run "mkdir -p '$(dirname "$dest")'"
      run "mv '$target' '$dest'"
    done < <(cd "$DOTFILES/$pkg" && find . \( -type f -o -type l \) ! -name .DS_Store | sed 's|^\./||')
    (( found )) && ok "Бэкап: ~/.dotfiles-backup/$stamp/"
    return 0
  }

  echo "Каждый пакет подключается отдельно, симлинками в \$HOME."
  echo ""
  for pkg in "${PACKAGES[@]}"; do
    [[ -d "$DOTFILES/$pkg" ]] || continue
    case "$pkg" in
      zsh)     desc="шелл: история, алиасы, fzf, zoxide, p10k" ;;
      git)     desc="настройки, алиасы, delta, глобальный ignore" ;;
      nvim)    desc="редактор: YAML/k8s, Markdown, логи, Go, git" ;;
      lazygit) desc="TUI для git" ;;
      tig)     desc="история и blame в консоли" ;;
      k9s)     desc="TUI для kubernetes: поды, логи, рестарт" ;;
      sec)     desc="dev-секреты в Keychain: sec add/get/cp, экспорт для переезда" ;;
      *)       desc="$pkg" ;;
    esac

    if ask "Подключить $pkg? ($desc)"; then
      backup_conflicts "$pkg"
      # --no-folding принципиально: без него stow подменяет каталог
      # ~/.config/zsh симлинком на репозиторий, и всё, что туда пишут
      # (история, кеши, oh-my-zsh), оказывается в рабочей копии git.
      run "stow ${STOW_OPTS[*]} -d '$DOTFILES' -t '$HOME' --restow '$pkg'"
      ok "$pkg подключён"
    fi
  done

  run "mkdir -p '$XDG_STATE/zsh'"
fi

# ═══════════════════════════════════════════════════════════════
#  4. Oh-My-Zsh, тема и плагины
# ═══════════════════════════════════════════════════════════════
header "Zsh: Oh-My-Zsh, тема, плагины"

echo "  oh-my-zsh               — фреймворк"
echo "  powerlevel10k           — тема (конфиг .p10k.zsh уже в репозитории)"
echo "  zsh-autosuggestions     — подсказки из истории"
echo "  zsh-syntax-highlighting — подсветка команд при наборе"
echo "  forgit                  — интерактивный git через fzf (glo, gd, gcb…)"
echo ""

if ask "Установить Oh-My-Zsh и плагины?"; then
  if [[ ! -d "$ZSH_DIR" ]]; then
    info "Ставлю Oh-My-Zsh…"
    # ZDOTDIR и KEEP_ZSHRC: иначе установщик создаёт свой ~/.zshrc-шаблон,
    # который при нашей раскладке (ZDOTDIR=~/.config/zsh) не читается и
    # только сбивает с толку. Ошибка установщика не должна ронять скрипт:
    # дальше ещё идентичности git.
    if ! run "ZSH='$ZSH_DIR' ZDOTDIR='$XDG_CONFIG/zsh' KEEP_ZSHRC=yes RUNZSH=no CHSH=no sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" '' --unattended"; then
      warn "Oh-My-Zsh не установился, см. вывод выше. Остальные шаги продолжаются."
    fi
  else
    ok "Oh-My-Zsh уже установлен"
  fi

  clone_once() {
    local url="$1" dir="$2" name="$3"
    if [[ -d "$dir" ]]; then
      ok "$name уже установлен"
    else
      info "Ставлю ${name}…"
      run "git clone --depth=1 '$url' '$dir'" || warn "$name: не удалось клонировать"
    fi
  }
  clone_once https://github.com/romkatv/powerlevel10k.git \
             "$ZSH_DIR/custom/themes/powerlevel10k" powerlevel10k
  clone_once https://github.com/zsh-users/zsh-autosuggestions \
             "$ZSH_DIR/custom/plugins/zsh-autosuggestions" zsh-autosuggestions
  clone_once https://github.com/zsh-users/zsh-syntax-highlighting \
             "$ZSH_DIR/custom/plugins/zsh-syntax-highlighting" zsh-syntax-highlighting
  clone_once https://github.com/wfxr/forgit \
             "$ZSH_DIR/custom/plugins/forgit" forgit

  # Шаблон ~/.zshrc, оставшийся от прежнего запуска установщика Oh-My-Zsh.
  # zsh его не читает (конфиг живёт в ZDOTDIR), но пусть не вводит в заблуждение.
  if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]] \
     && grep -q 'Path to your Oh My Zsh installation' "$HOME/.zshrc" 2>/dev/null; then
    stamp="$(date +%Y%m%d-%H%M%S)"
    # shellcheck disable=SC2088  # ~ здесь просто текст сообщения, не путь
    warn "~/.zshrc — шаблон установщика Oh-My-Zsh, не используется; переношу в ~/.dotfiles-backup/${stamp}/"
    run "mkdir -p '$HOME/.dotfiles-backup/$stamp'"
    run "mv '$HOME/.zshrc' '$HOME/.dotfiles-backup/$stamp/.zshrc'"
  fi

  # Тема bat под ту же Catppuccin, что в nvim (BAT_THEME в conf.d/20-tools.zsh)
  if command -v bat &>/dev/null; then
    bat_themes="$(bat --config-dir)/themes"
    if [[ ! -f "$bat_themes/Catppuccin Mocha.tmTheme" ]]; then
      info "Ставлю тему Catppuccin Mocha для bat…"
      run "mkdir -p '$bat_themes'"
      run "curl -fsSL -o '$bat_themes/Catppuccin Mocha.tmTheme' https://raw.githubusercontent.com/catppuccin/bat/main/themes/Catppuccin%20Mocha.tmTheme && bat cache --build >/dev/null" \
        || warn "тема bat не установилась — bat будет с темой по умолчанию"
    else
      ok "тема bat уже установлена"
    fi
  fi

  if [[ "$SHELL" != */zsh ]] && command -v zsh &>/dev/null; then
    if ask "Сделать zsh шеллом по умолчанию? (сейчас $SHELL)"; then
      run "chsh -s '$(command -v zsh)'"
    fi
  fi
fi

# ═══════════════════════════════════════════════════════════════
#  5. Git: идентичности
# ═══════════════════════════════════════════════════════════════
header "Git: идентичности"

setup_identity() {
  cat <<'TXT'
  Имя и почта НЕ хранятся в репозитории — они создаются здесь,
  в ~/.config/git/identity (этот файл в git не попадает).

  По умолчанию используется личная почта. Для рабочих репозиториев
  можно задать отдельные аккаунты, привязанные к каталогу: всё,
  что лежит внутри указанного пути, подписывается своей почтой.

TXT

  local name email
  name="$(oneline "$(askreq "Имя для коммитов" "$(git config --global user.name 2>/dev/null || true)")")"
  email="$(oneline "$(askreq "Личная почта (используется по умолчанию)")")"

  if (( DRY_RUN )); then
    info "[dry-run] записал бы $IDENTITY"
    return 0
  fi

  mkdir -p "$XDG_CONFIG/git"
  umask 077
  cat > "$IDENTITY" <<EOT
# Создано install.sh. В git не коммитится.
# Личная идентичность — действует везде, кроме путей ниже.
[user]
	name = $name
	email = $email
EOT

  # Дополнительные аккаунты, привязанные к каталогу
  local n=0
  while ask "Добавить ещё один аккаунт (например рабочий)?"; do
    local slug path aname aemail
    slug="$(askreq "Короткое имя профиля (латиницей, без пробелов)" "work")"
    slug="$(printf '%s' "$slug" | tr -cd '[:alnum:]._-')"
    [[ -z "$slug" ]] && slug="work$n"

    # shellcheck disable=SC2088  # ~ здесь литерал: его раскрывает git, а не шелл
    path="$(askreq "Каталог, внутри которого действует этот аккаунт" "~/work/")"
    # Приводим к виду ~/…/ — git понимает ~ в gitdir и требует
    # завершающий слэш, чтобы правило покрывало подкаталоги.
    path="${path/#$HOME/\~}"
    [[ "$path" != */ ]] && path="$path/"

    aname="$(oneline "$(askreq "Имя для коммитов в $path" "$name")")"
    aemail="$(oneline "$(askreq "Почта для $path")")"

    cat > "$XDG_CONFIG/git/identity.$slug" <<EOT
# Создано install.sh. В git не коммитится.
[user]
	name = $aname
	email = $aemail
EOT
    cat >> "$IDENTITY" <<EOT

[includeIf "gitdir:$path"]
	path = ~/.config/git/identity.$slug
EOT
    ok "Аккаунт «${slug}» ($aemail) действует внутри $path"
    n=$((n + 1))
  done

  ok "Идентичности записаны в $IDENTITY"
  echo ""
  info "Проверить в любом репозитории:  git whoami"
}

if [[ -f "$IDENTITY" ]]; then
  ok "Идентичности уже настроены:"
  grep -E '^\s*(name|email) =|^\[includeIf' "$IDENTITY" 2>/dev/null | sed 's/^/    /' || true
  if ask "Настроить заново?"; then setup_identity; fi
else
  setup_identity
fi

# ═══════════════════════════════════════════════════════════════
#  6. Настройки macOS
# ═══════════════════════════════════════════════════════════════
if [[ "$(uname -s)" == "Darwin" ]]; then
  header "Настройки macOS"
  echo "  Автоповтор клавиш, отключение автозамены кавычек, показ расширений"
  echo "  и скрытых файлов в Finder, каталог скриншотов, поведение Dock."
  echo ""
  if ask "Применить системные настройки? (обратимо)"; then
    run "'$DOTFILES/macos/defaults.sh'"
  fi

  if [[ -d /Applications/QLMarkdown.app ]]; then
    echo ""
    echo "  Quick Look: пробел на .md в Finder покажет отрендеренный Markdown"
    echo "  вместо простыни текста. Расширение регистрируется одним запуском"
    echo "  QLMarkdown; настройки берутся из macos/qlmarkdown.plist, если он есть."
    echo ""
    if ask "Включить Quick Look для Markdown?"; then
      run "'$DOTFILES/macos/quicklook.sh'" || warn "Quick Look не включился, см. вывод выше"
    fi
  fi

  echo ""
  echo "  Шпаргалка по nvim в Dock: значок «Шпаргалка nvim» открывает"
  echo "  docs/nvim-cheatsheet.html одним кликом. Повторный запуск не создаёт второй."
  echo ""
  if ask "Закрепить шпаргалку по nvim в Dock?"; then
    run "'$DOTFILES/macos/dock.sh'" || warn "Значок в Dock не появился, см. вывод выше"
  fi
fi

# ═══════════════════════════════════════════════════════════════
#  Итог
# ═══════════════════════════════════════════════════════════════
(( DRY_RUN )) || check_all

header "Готово"
cat <<TXT
Дальше:

  1. Перезапустить шелл:            exec zsh
  2. iTerm2 → Settings → Profiles:
       • Text → Font           →  MesloLGS Nerd Font Mono
       • Keys → Left Option    →  Esc+     (для навигации Option+Стрелки)
  3. Проверить идентичность в репозитории:   git whoami
  4. При первом запуске nvim плагины и LSP-серверы поставятся сами.
  5. Повторить проверку в любой момент:      make check

Шпаргалка (полная — cheat, по nvim — cheat nvim, по kubernetes — cheat k8s):
  Ctrl+R  поиск по истории      Ctrl+T  поиск файлов      Alt+C  переход в каталог
  glo     лог (fzf)             gd      diff (fzf)        gcb    ветки (fzf)
  git lg / lga / ll / bra / bl  история, ветки, blame     lg     lazygit
  tig / tig blame <файл>        история и авторство в консоли

Локальные настройки и секреты, которые не должны попасть в git:
  ~/.config/zsh/local.zsh
TXT
