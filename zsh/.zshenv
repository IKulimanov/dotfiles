# ~/.zshenv — читается первым и для ВСЕХ шеллов (включая неинтерактивные).
# Здесь только переменные окружения: то, что должно быть видно скриптам
# и GUI-приложениям, запущенным не из терминала.

# --- XDG ---
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# zsh ищет свои конфиги здесь
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# --- PATH ---
# Именно в .zshenv, а не в .zshrc: иначе IntelliJ IDEA и прочие приложения,
# запущенные из Dock, не увидят ~/bin и ~/.local/bin.
typeset -U path                       # без дубликатов
path=("$HOME/bin" "$HOME/.local/bin" $path)
export PATH

# --- Локаль ---
# Только LANG. LC_ALL перекрывает все категории разом и не даёт
# переопределить, скажем, LC_COLLATE в конкретной команде.
export LANG=en_US.UTF-8

# --- Редактор ---
export EDITOR=nvim
export VISUAL=nvim
export PAGER=less
export LESS='-R -F -X'

# --- Где лежат сами dotfiles ---
# Вычисляется из симлинка ~/.zshenv → <репозиторий>/zsh/.zshenv,
# поэтому репозиторий можно клонировать куда угодно. Алиас: dot
[[ -L "$HOME/.zshenv" ]] && export DOTFILES="${${:-$HOME/.zshenv}:A:h:h}"
