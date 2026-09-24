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

# ── Шпаргалки ──────────────────────────────────────────────────
# HTML-файлы в docs/, без внешних запросов: открываются без интернета
# и работают, даже когда сломан сам шелл.
#   cheat          весь конфиг
#   cheat nvim     как работать в nvim (она же — значок в Dock, make dock)
#   cheat k8s      kubernetes по шагам
#   cheat -t …     показать в терминале (нужен lynx или w3m; иначе подскажет)
cheat() {
  local text=0 topic="" arg name
  for arg in "$@"; do
    if [[ "$arg" == "-t" ]]; then text=1; else topic="$arg"; fi
  done
  case "$topic" in
    "")       name=cheatsheet ;;
    nvim|vim) name=nvim-cheatsheet ;;
    k8s|kube) name=k8s-cheatsheet ;;
    *) print -u2 "Нет шпаргалки «$topic». Есть: cheat, cheat nvim, cheat k8s"; return 2 ;;
  esac
  local f="${DOTFILES:-$HOME/dotfiles}/docs/$name.html"
  if [[ ! -f "$f" ]]; then
    print -u2 "Шпаргалка не найдена: $f"
    return 1
  fi
  if (( text )); then
    if command -v w3m &>/dev/null;   then w3m -dump "$f" | ${PAGER:-less}
    elif command -v lynx &>/dev/null; then lynx -dump "$f" | ${PAGER:-less}
    else print -u2 "Для текстового режима нужен w3m или lynx: brew install w3m"; return 1
    fi
  else
    open "$f"
  fi
}
