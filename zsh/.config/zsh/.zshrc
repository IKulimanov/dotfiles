# ~/.config/zsh/.zshrc
# ------------------------------------------------

export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"

# --- Powerlevel10k instant prompt (должен быть первым) ---
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# --- Oh-My-Zsh ---
export ZSH="$ZDOTDIR/oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  zsh-syntax-highlighting
  zsh-autosuggestions
  direnv                    # авто-загрузка .envrc
)

source "$ZSH/oh-my-zsh.sh"

# --- Powerlevel10k ---
[[ -f "$ZDOTDIR/.p10k.zsh" ]] && source "$ZDOTDIR/.p10k.zsh"

# =====================================================
# Навигация по словам (Option+Arrow в iTerm2/Terminal)
# =====================================================
# Option+Left/Right — перемещение по словам
bindkey "^[[1;3D" backward-word        # Option+Left
bindkey "^[[1;3C" forward-word         # Option+Right
# Option+Backspace — удаление слова назад
bindkey "^[^?" backward-kill-word      # Option+Backspace
# Option+Delete — удаление слова вперёд (fn+Option+Backspace)
bindkey "^[[3;3~" kill-word            # Option+Delete (fn+opt+backspace)
# Cmd+Left/Right — начало/конец строки (для iTerm2)
bindkey "^[[1;2D" beginning-of-line    # Shift+Left (или Cmd в iTerm)
bindkey "^[[1;2C" end-of-line          # Shift+Right

# =====================================================
# История
# =====================================================
HISTFILE="$ZDOTDIR/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS    # не дублировать в истории
setopt HIST_FIND_NO_DUPS       # не показывать дубли при поиске
setopt HIST_REDUCE_BLANKS      # убирать лишние пробелы
setopt SHARE_HISTORY           # шарить историю между сессиями
setopt INC_APPEND_HISTORY      # писать сразу, не ждать выхода

# =====================================================
# Автодополнение
# =====================================================
setopt COMPLETE_IN_WORD        # дополнять в середине слова
setopt AUTO_MENU               # показывать меню при повторном Tab
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # регистро-независимо

# =====================================================
# Удобства
# =====================================================
setopt AUTO_CD                 # cd без ввода cd
setopt CORRECT                 # предлагать исправление опечаток

# =====================================================
# fzf — fuzzy finder (Ctrl+R для истории, Ctrl+T для файлов)
# =====================================================
if command -v fzf &>/dev/null; then
  source <(fzf --zsh 2>/dev/null) || true
  export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border"
  # Использовать fd вместо find, если доступен
  if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND="fd --type f --hidden --exclude .git"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  fi
fi

# =====================================================
# zoxide — умный cd (z <dir>)
# =====================================================
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# =====================================================
# Алиасы
# =====================================================
# ls → eza (современная замена ls)
if command -v eza &>/dev/null; then
  alias ls="eza --icons"
  alias ll="eza --icons -la"
  alias lt="eza --icons --tree --level=2"
elif command -v colorls &>/dev/null; then
  alias ls="colorls"
  alias ll="colorls -la"
fi

# Безопасность
alias rm="rm -i"
alias mv="mv -i"
alias cp="cp -i"

# Git (короткие)
alias g="git"
alias gs="git status"
alias gd="git diff"
alias gl="git log --oneline --graph -20"

# Docker
alias dc="docker compose"
alias dps="docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

# Разное
alias path='echo $PATH | tr ":" "\n"'
alias reload='source "$ZDOTDIR/.zshrc"'

# =====================================================
# PATH
# =====================================================
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

# =====================================================
# Локаль
# =====================================================
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# =====================================================
# SDK / версии языков (подключаются если установлены)
# =====================================================
command -v rbenv  &>/dev/null && eval "$(rbenv init - zsh)"

# --- Локальные переопределения (не в git) ---
[[ -f "$ZDOTDIR/.zshrc.local" ]] && source "$ZDOTDIR/.zshrc.local"
