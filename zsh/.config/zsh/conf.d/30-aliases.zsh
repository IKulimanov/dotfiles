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
# Интерактивные команды (fzf) даёт плагин forgit:
#   glo  лог с превью        gd   diff по файлам       gcb  переключить ветку
#   ga   add по файлам       gcf  откатить файл        gss  stash
#   gbl  blame               grh  reset HEAD по файлам gclean  удалить untracked
# Остальное — алиасы git из git/.config/git/config: git lg, lga, ll, bra, bl, msg…
alias g="git"
alias gs="git status -sb"
alias gl="git lg"           # граф: хеш, дата, автор, ветки, сообщение
alias gla="git lga"         # то же по всем веткам
alias gb="git bra"          # ветки: когда, кто, что
alias lg="lazygit"
# какой идентичностью подписан текущий репозиторий (личной или рабочей)
alias gw="git whoami"

# ── docker ─────────────────────────────────────────────────────
alias dc="docker compose"
alias dps="docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

# ── прочее ─────────────────────────────────────────────────────
alias path='echo $PATH | tr ":" "\n"'
alias reload='exec zsh'
command -v nvim &>/dev/null && alias vim="nvim"

# Быстрый доступ к самим dotfiles ($DOTFILES вычисляется в .zshenv)
alias dot='cd "${DOTFILES:-$HOME/dotfiles}"'
