# Каждый инструмент подключается только если установлен —
# конфиг остаётся рабочим на машине, где чего-то нет.

# ── fzf — Ctrl+R история, Ctrl+T файлы, Alt+C каталоги ─────────
if command -v fzf &>/dev/null; then
  if fzf --zsh &>/dev/null; then
    source <(fzf --zsh)                    # fzf >= 0.48
  else
    [[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
  fi

  export FZF_DEFAULT_OPTS="--height=45% --layout=reverse --border=rounded --info=inline"

  if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND="fd --type f --hidden --exclude .git"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND="fd --type d --hidden --exclude .git"
  fi

  # Превью: bat для файлов, eza для каталогов
  command -v bat &>/dev/null && \
    export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
  command -v eza &>/dev/null && \
    export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always {}'"
fi

# ── zoxide — умный cd (z <часть имени>) ────────────────────────
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# ── mise — версии Go / Node / Python по каталогу ───────────────
# Заменил rbenv: Ruby в работе не используется, а Go и Node — да.
# Версии задаются глобально в ~/.config/mise/config.toml
# и переопределяются файлом .mise.toml в конкретном проекте.
command -v mise &>/dev/null && eval "$(mise activate zsh)"

# ── direnv — авто-загрузка .envrc при входе в каталог ──────────
# Если пользуетесь mise, его секция [env] закрывает ту же задачу.
command -v direnv &>/dev/null && eval "$(direnv hook zsh)"

# ── bat — тема под ту же Catppuccin, что в nvim ────────────────
command -v bat &>/dev/null && export BAT_THEME="Catppuccin Mocha"
