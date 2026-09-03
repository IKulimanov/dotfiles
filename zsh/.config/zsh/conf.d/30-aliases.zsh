# ── ls → eza ───────────────────────────────────────────────────
if command -v eza &>/dev/null; then
  alias ls="eza --icons --group-directories-first"
  alias ll="eza --icons --group-directories-first -la --git"
  alias lt="eza --icons --tree --level=2 --git-ignore"
fi

# ── Удаление ───────────────────────────────────────────────────
# rm -i защищает только до тех пор, пока не надоест: дальше
# вырабатывается рефлекс rm -rf, при котором -i игнорируется.
# trash кладёт в Корзину, то есть удаление обратимо по-настоящему.
# Настоящий rm остаётся доступен как \rm или /bin/rm.
command -v trash &>/dev/null && alias rm="trash"
alias mv="mv -i"
alias cp="cp -i"

# ── git ────────────────────────────────────────────────────────
alias g="git"
alias gs="git status"
alias gd="git diff"
alias gl="git log --oneline --graph -20"
# какой идентичностью подписан текущий репозиторий (личной или рабочей)
alias gw="git whoami"

# ── docker ─────────────────────────────────────────────────────
alias dc="docker compose"
alias dps="docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

# ── прочее ─────────────────────────────────────────────────────
alias path='echo $PATH | tr ":" "\n"'
alias reload='exec zsh'
command -v nvim &>/dev/null && alias vim="nvim"

# Быстрый доступ к самим dotfiles
alias dot='cd "${DOTFILES:-$HOME/.dotfiles}"'
