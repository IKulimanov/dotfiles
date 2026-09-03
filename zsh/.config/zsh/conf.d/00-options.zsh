# ── История ────────────────────────────────────────────────────
# Файл истории живёт в $XDG_STATE_HOME, а НЕ в $ZDOTDIR:
# из-за stow каталог ~/.config/zsh — симлинк в git-репозиторий,
# и история (а в ней токены и пароли из argv) попадала бы в рабочую копию.
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
[[ -d "${HISTFILE:h}" ]] || mkdir -p "${HISTFILE:h}"
HISTSIZE=50000
SAVEHIST=50000

setopt HIST_IGNORE_ALL_DUPS    # не дублировать
setopt HIST_FIND_NO_DUPS       # не показывать дубли при поиске
setopt HIST_REDUCE_BLANKS      # убирать лишние пробелы
setopt HIST_IGNORE_SPACE       # команда с ведущим пробелом не попадёт в историю
setopt EXTENDED_HISTORY        # писать время и длительность
setopt HIST_VERIFY             # !! сначала подставить в строку, а не выполнить
setopt SHARE_HISTORY           # общая история между сессиями
                               # (включает инкрементальную дозапись — отдельный
                               #  INC_APPEND_HISTORY был бы избыточен)

# ── Автодополнение ─────────────────────────────────────────────
setopt COMPLETE_IN_WORD
setopt AUTO_MENU
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'   # регистронезависимо
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"
zstyle ':completion:*' use-cache on

# ── Навигация ──────────────────────────────────────────────────
setopt AUTO_CD                 # cd без ввода cd
setopt AUTO_PUSHD              # каждый cd кладётся в стек
setopt PUSHD_IGNORE_DUPS
setopt EXTENDED_GLOB
setopt INTERACTIVE_COMMENTS    # # в интерактивной строке — комментарий

# CORRECT намеренно выключен: он регулярно предлагает «исправить»
# подкоманды git/kubectl и имена каталогов. Автодополнение и история
# закрывают эту задачу без ложных срабатываний.
unsetopt CORRECT
