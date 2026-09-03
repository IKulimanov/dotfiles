#!/usr/bin/env bash
# Установщик dotfiles. Безопасно перезапускается: каждый шаг проверяет,
# не сделан ли он уже, и спрашивает подтверждение.
#
#   ./install.sh              обычный интерактивный запуск
#   ./install.sh --dry-run    показать, что будет сделано, ничего не меняя
#   ./install.sh --yes        не задавать вопросов (для новой машины)
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
PACKAGES=(zsh git nvim)

ASSUME_YES=0
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y)    ASSUME_YES=1 ;;
    --dry-run|-n) DRY_RUN=1 ;;
    --help|-h)   sed -n '2,8p' "$0"; exit 0 ;;
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

# Спрашивает, пока не получит непустой ответ
askreq() {
  local v=""
  while [[ -z "$v" ]]; do
    v="$(askval "$1" "${2:-}")"
    [[ -z "$v" ]] && warn "Значение обязательно."
    [[ ! -e /dev/tty ]] && break
  done
  printf '%s' "$v"
}

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
    "CLI-инструменты, на которые опирается конфиг: stow, шрифт MesloLGS NF,
  bat, eza, fd, ripgrep, fzf, zoxide, jq, trash, neovim, gh, delta, lazygit,
  direnv, mise. Шрифт обязателен — без него промпт рисует квадраты."

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
  warn "gnu-stow не установлен — конфиги не подключены."
  warn "Установите (brew install gnu-stow) и запустите скрипт снова."
else
  # Файл считается «нашим», если это симлинк внутрь каталога dotfiles.
  is_ours() {
    [[ -L "$1" ]] || return 1
    local link; link="$(readlink "$1")"
    [[ "$link" == "$DOTFILES"/* || "$link" == *"/$(basename "$DOTFILES")/"* ]]
  }

  backup_conflicts() {
    local pkg="$1" rel target stamp dest found=0
    stamp="$(date +%Y%m%d-%H%M%S)"
    while IFS= read -r rel; do
      target="$HOME/$rel"
      [[ -e "$target" || -L "$target" ]] || continue
      is_ours "$target" && continue
      if (( found == 0 )); then
        warn "В \$HOME уже есть файлы из пакета «$pkg» — переношу в бэкап:"
        found=1
      fi
      dest="$HOME/.dotfiles-backup/$stamp/$rel"
      echo "    $rel"
      run "mkdir -p '$(dirname "$dest")'"
      run "mv '$target' '$dest'"
    done < <(cd "$DOTFILES/$pkg" && find . \( -type f -o -type l \) | sed 's|^\./||')
    (( found )) && ok "Бэкап: ~/.dotfiles-backup/$stamp/"
    return 0
  }

  echo "Каждый пакет подключается отдельно, симлинками в \$HOME."
  echo ""
  for pkg in "${PACKAGES[@]}"; do
    [[ -d "$DOTFILES/$pkg" ]] || continue
    case "$pkg" in
      zsh)  desc="шелл: история, алиасы, fzf, zoxide, p10k" ;;
      git)  desc="настройки, алиасы, delta, глобальный ignore" ;;
      nvim) desc="редактор: YAML/k8s, Markdown, логи, Go" ;;
      *)    desc="$pkg" ;;
    esac

    if ask "Подключить $pkg? ($desc)"; then
      backup_conflicts "$pkg"
      # --no-folding принципиально: без него stow подменяет каталог
      # ~/.config/zsh симлинком на репозиторий, и всё, что туда пишут
      # (история, кеши, oh-my-zsh), оказывается в рабочей копии git.
      run "stow --no-folding -d '$DOTFILES' -t '$HOME' --restow '$pkg'"
      ok "$pkg подключён"
    fi
  done

  run "mkdir -p '$XDG_STATE/zsh'"
fi

# ═══════════════════════════════════════════════════════════════
#  4. Oh-My-Zsh, тема и плагины
# ═══════════════════════════════════════════════════════════════
header "Zsh: Oh-My-Zsh, тема, плагины"

ZSH_DIR="$XDG_CONFIG/zsh/oh-my-zsh"
echo "  oh-my-zsh               — фреймворк"
echo "  powerlevel10k           — тема (конфиг .p10k.zsh уже в репозитории)"
echo "  zsh-autosuggestions     — подсказки из истории"
echo "  zsh-syntax-highlighting — подсветка команд при наборе"
echo ""

if ask "Установить Oh-My-Zsh и плагины?"; then
  if [[ ! -d "$ZSH_DIR" ]]; then
    info "Ставлю Oh-My-Zsh…"
    run "ZSH='$ZSH_DIR' sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" '' --unattended --keep-zshrc"
  else
    ok "Oh-My-Zsh уже установлен"
  fi

  clone_once() {
    local url="$1" dir="$2" name="$3"
    if [[ -d "$dir" ]]; then
      ok "$name уже установлен"
    else
      info "Ставлю $name…"
      run "git clone --depth=1 '$url' '$dir'"
    fi
  }
  clone_once https://github.com/romkatv/powerlevel10k.git \
             "$ZSH_DIR/custom/themes/powerlevel10k" powerlevel10k
  clone_once https://github.com/zsh-users/zsh-autosuggestions \
             "$ZSH_DIR/custom/plugins/zsh-autosuggestions" zsh-autosuggestions
  clone_once https://github.com/zsh-users/zsh-syntax-highlighting \
             "$ZSH_DIR/custom/plugins/zsh-syntax-highlighting" zsh-syntax-highlighting
fi

# ═══════════════════════════════════════════════════════════════
#  5. Git: идентичности
# ═══════════════════════════════════════════════════════════════
header "Git: идентичности"

IDENTITY="$XDG_CONFIG/git/identity"

setup_identity() {
  cat <<'TXT'
  Имя и почта НЕ хранятся в репозитории — они создаются здесь,
  в ~/.config/git/identity (этот файл в git не попадает).

  По умолчанию используется личная почта. Для рабочих репозиториев
  можно задать отдельные аккаунты, привязанные к каталогу: всё,
  что лежит внутри указанного пути, подписывается своей почтой.

TXT

  local name email
  name="$(askreq "Имя для коммитов" "$(git config --global user.name 2>/dev/null || true)")"
  email="$(askreq "Личная почта (используется по умолчанию)")"

  if (( DRY_RUN )); then
    info "[dry-run] записал бы $IDENTITY"
    return 0
  fi

  mkdir -p "$XDG_CONFIG/git"
  umask 077
  cat > "$IDENTITY" <<EOF
# Создано install.sh. В git не коммитится.
# Личная идентичность — действует везде, кроме путей ниже.
[user]
	name = $name
	email = $email
EOF

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

    aname="$(askreq "Имя для коммитов в $path" "$name")"
    aemail="$(askreq "Почта для $path")"

    cat > "$XDG_CONFIG/git/identity.$slug" <<EOF
# Создано install.sh. В git не коммитится.
[user]
	name = $aname
	email = $aemail
EOF
    cat >> "$IDENTITY" <<EOF

[includeIf "gitdir:$path"]
	path = ~/.config/git/identity.$slug
EOF
    ok "Аккаунт «$slug» ($aemail) действует внутри $path"
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
fi

# ═══════════════════════════════════════════════════════════════
#  Итог
# ═══════════════════════════════════════════════════════════════
header "Готово"
cat <<TXT
Дальше:

  1. Перезапустить шелл:            exec zsh
  2. iTerm2 → Settings → Profiles:
       • Text → Font           →  MesloLGS NF
       • Keys → Left Option    →  Esc+     (для навигации Option+Стрелки)
  3. Проверить идентичность в репозитории:   git whoami
  4. При первом запуске nvim плагины и LSP-серверы поставятся сами.

Шпаргалка:
  Ctrl+R  поиск по истории      Ctrl+T  поиск файлов
  Alt+C   переход в каталог     z <имя> умный cd
  -       файловый менеджер в nvim (oil)

Локальные настройки и секреты, которые не должны попасть в git:
  ~/.config/zsh/local.zsh
TXT
