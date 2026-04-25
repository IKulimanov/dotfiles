#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

# ── Цвета ──
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}▸${NC} $*"; }
ok()      { echo -e "${GREEN}✓${NC} $*"; }
warn()    { echo -e "${YELLOW}!${NC} $*"; }
header()  { echo -e "\n${BOLD}═══ $* ═══${NC}\n"; }

ask() {
  local prompt="$1"
  read -rp "$(echo -e "${BOLD}$prompt${NC} [y/N] ")" answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

# ── Homebrew ──
header "Homebrew"
if command -v brew &>/dev/null; then
  ok "Homebrew уже установлен"
else
  if ask "Установить Homebrew? (менеджер пакетов для macOS)"; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    warn "Без Homebrew установка пакетов невозможна"
  fi
fi

# ── Brew пакеты (по группам) ──
if command -v brew &>/dev/null; then

  header "CLI инструменты"
  echo "  gnu-stow   — менеджер симлинков (нужен для установки конфигов)"
  echo "  bat        — cat с подсветкой синтаксиса"
  echo "  eza        — современная замена ls с иконками"
  echo "  ripgrep    — быстрый поиск по содержимому файлов"
  echo "  fd         — быстрый поиск файлов по имени"
  echo "  fzf        — fuzzy finder (Ctrl+R — история, Ctrl+T — файлы)"
  echo "  zoxide     — умный cd, запоминает часто посещаемые каталоги"
  echo "  jq         — парсер JSON в командной строке"
  echo "  htop       — мониторинг процессов"
  echo "  tldr       — краткие примеры команд (вместо длинных man)"
  echo ""
  if ask "Установить CLI инструменты?"; then
    brew install gnu-stow bat eza ripgrep fd fzf zoxide jq htop tldr
    ok "CLI инструменты установлены"
  fi

  header "Git инструменты"
  echo "  gh         — GitHub CLI (создание PR, issues из терминала)"
  echo "  git-delta  — красивые диффы (side-by-side, подсветка синтаксиса)"
  echo "  lazygit    — TUI интерфейс для git"
  echo ""
  if ask "Установить Git инструменты?"; then
    brew install gh git-delta lazygit
    ok "Git инструменты установлены"
  fi

  header "Инструменты разработки"
  echo "  neovim     — текстовый редактор"
  echo "  direnv     — авто-загрузка .envrc при входе в каталог"
  echo ""
  if ask "Установить инструменты разработки?"; then
    brew install neovim direnv
    ok "Инструменты разработки установлены"
  fi

  header "GUI приложения"
  echo "  iterm2     — продвинутый терминал (сплиты, профили, поиск)"
  echo "  docker     — Docker Desktop"
  echo ""
  if ask "Установить GUI приложения?"; then
    brew install --cask iterm2 docker
    ok "GUI приложения установлены"
  fi
fi

# ── Oh-My-Zsh + плагины ──
header "Zsh: Oh-My-Zsh + плагины"
echo "  oh-my-zsh              — фреймворк для zsh"
echo "  powerlevel10k          — быстрая информативная тема"
echo "  zsh-autosuggestions    — предложения из истории (серый текст)"
echo "  zsh-syntax-highlighting — подсветка команд при наборе"
echo ""

ZSH_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/oh-my-zsh"

if ask "Установить Oh-My-Zsh и плагины?"; then
  if [[ ! -d "$ZSH_DIR" ]]; then
    info "Устанавливаю Oh-My-Zsh..."
    ZSH="$ZSH_DIR" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" \
      --unattended --keep-zshrc
    ok "Oh-My-Zsh установлен"
  else
    ok "Oh-My-Zsh уже установлен"
  fi

  # Тема
  P10K_DIR="$ZSH_DIR/custom/themes/powerlevel10k"
  if [[ ! -d "$P10K_DIR" ]]; then
    info "Устанавливаю Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
    ok "Powerlevel10k установлен"
  else
    ok "Powerlevel10k уже установлен"
  fi

  # Плагины
  PLUGINS_DIR="$ZSH_DIR/custom/plugins"

  if [[ ! -d "$PLUGINS_DIR/zsh-autosuggestions" ]]; then
    info "Устанавливаю zsh-autosuggestions..."
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$PLUGINS_DIR/zsh-autosuggestions"
  else
    ok "zsh-autosuggestions уже установлен"
  fi

  if [[ ! -d "$PLUGINS_DIR/zsh-syntax-highlighting" ]]; then
    info "Устанавливаю zsh-syntax-highlighting..."
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$PLUGINS_DIR/zsh-syntax-highlighting"
  else
    ok "zsh-syntax-highlighting уже установлен"
  fi
fi

# ── Stow: линковка конфигов ──
if ! command -v stow &>/dev/null; then
  warn "gnu-stow не установлен — пропускаю линковку конфигов"
  warn "Установи: brew install gnu-stow, затем запусти скрипт снова"
else
  header "Линковка конфигов (GNU Stow)"
  echo "Каждый конфиг устанавливается отдельно симлинком в \$HOME"
  echo ""

  for pkg in zsh git nvim; do
    if [[ ! -d "$DOTFILES/$pkg" ]]; then
      continue
    fi

    case "$pkg" in
      zsh)  desc="Zsh — шелл, алиасы, история, fzf, zoxide" ;;
      git)  desc="Git — настройки, алиасы, delta, global ignore" ;;
      nvim) desc="Neovim — редактор с LSP, telescope, treesitter" ;;
      *)    desc="$pkg" ;;
    esac

    if ask "Подключить $pkg? ($desc)"; then
      info "Линкую $pkg..."
      stow -d "$DOTFILES" -t "$HOME" --restow "$pkg"
      ok "$pkg подключён"
    fi
  done
fi

# ── iTerm2: напоминание про Option ──
header "Готово!"
echo ""
echo "Рекомендации после установки:"
echo ""
echo "  1. Перезапусти терминал или выполни:  exec zsh"
echo "  2. Настрой тему:  p10k configure"
echo "  3. iTerm2 → Preferences → Profiles → Keys:"
echo "     Left Option key → Esc+  (для навигации Option+Arrow)"
echo "  4. fzf: Ctrl+R — поиск по истории, Ctrl+T — поиск файлов"
echo "  5. zoxide: z <dir> — умный переход в каталог"
echo ""
