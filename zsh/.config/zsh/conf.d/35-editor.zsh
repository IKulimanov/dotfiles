# ── Открыть nvim сразу в нужном месте ──────────────────────────
# EDITOR и VISUAL заданы в .zshenv; здесь только способы попасть
# в файл, не набирая путь и не листая его до нужной строки.

# v — nvim, понимающий file:line:col. Ровно тот формат, который
# печатают rg, grep -n, компиляторы и стектрейсы: можно скопировать
# строку из вывода и открыть её.
#   v README.md          обычное открытие
#   v README.md:42       курсор на строке 42
#   v README.md:42:7     строка 42, колонка 7
v() {
  emulate -L zsh
  (( $# )) || { nvim; return }

  local arg="$1"; shift
  # Двоеточие разбираем только если файла с таким именем нет:
  # имя вида «отчёт:2026.md» встречается редко, но ломать его незачем.
  if [[ ! -e "$arg" && "$arg" == *:* ]]; then
    local file="${arg%%:*}" rest="${arg#*:}"
    local line="${rest%%:*}" col=""
    [[ "$rest" == *:* ]] && { col="${rest#*:}"; col="${col%%:*}" }
    if [[ -e "$file" && "$line" == <-> ]]; then
      if [[ "$col" == <-> ]]; then
        nvim "$file" -c "call cursor($line, $col)" "$@"
      else
        nvim "+$line" "$file" "$@"
      fi
      return
    fi
  fi
  nvim "$arg" "$@"
}

# vf — выбрать файл через fzf и открыть. Список и превью те же,
# что у Ctrl+T (см. conf.d/20-tools.zsh), но Enter открывает nvim,
# а не подставляет путь в строку.
vf() {
  emulate -L zsh
  local file
  file="$(fzf --query="$*" ${FZF_CTRL_T_OPTS:+${=FZF_CTRL_T_OPTS}})" || return
  [[ -n "$file" ]] && nvim "$file"
}

# vg <текст> — найти по содержимому и открыть на найденной строке.
# Дополняет Space s в nvim: искать можно, ещё не открыв редактор.
vg() {
  emulate -L zsh
  if (( ! $# )); then
    print -u2 "vg <текст> — поиск по содержимому, Enter откроет nvim на строке"
    return 2
  fi
  local pick file line
  pick="$(rg --line-number --no-heading --color=always --smart-case -- "$*" \
    | fzf --ansi --delimiter=: \
          --preview 'bat --color=always --style=numbers --highlight-line {2} {1}' \
          --preview-window 'up,60%,+{2}-5')" || return
  [[ -n "$pick" ]] || return
  file="${pick%%:*}"
  line="${pick#*:}"; line="${line%%:*}"
  nvim "+$line" "$file"
}

# ── Чтение Markdown в терминале ────────────────────────────────
# glow рендерит: заголовки, списки, таблицы, код с подсветкой.
# bat в запасе — он только подсвечивает разметку, но есть всегда.
#   md README.md    прочитать файл
#   md              список md-файлов текущего каталога
# Oh-My-Zsh заводит alias md='mkdir -p', а на имени с алиасом zsh не даёт
# объявить функцию — файл падал с parse error. Каталог создаёт `take`.
unalias md 2>/dev/null
md() {
  emulate -L zsh
  if command -v glow &>/dev/null; then
    if (( $# )); then
      glow -p "$@"
    else
      glow
    fi
  elif command -v bat &>/dev/null; then
    bat --language=markdown "$@"
  else
    ${PAGER:-less} "$@"
  fi
}
