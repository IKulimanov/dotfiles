# ── sec — dev-секреты в отдельном Keychain ─────────────────────
# Скрипт: ~/bin/sec (пакет sec). Здесь автодополнение и короткий алиас sc.
#   sec <Tab>        команды с описанием
#   sec get k8s/<Tab>  имена записей по префиксу (кэш 60 с)

_sec_names() {
  local -a names
  names=(${(f)"$(sec names 2>/dev/null)"})
  (( ${#names} )) && _describe -t names 'запись' names
}

_sec() {
  local -a cmds=(
    'add:сохранить секрет (скрытый ввод, stdin или файл)'
    'get:секрет в stdout'
    'cp:секрет в буфер обмена'
    'out:восстановить файл на диск'
    'ls:список записей'
    'show:метаданные записи'
    'rm:удалить запись'
    'env:подставить секреты в окружение команды'
    'pick:выбрать через fzf'
    'export:экспорт в файл age'
    'import:импорт из файла age'
    'init:создать или подключить keychain'
    'lock:заблокировать keychain'
    'unlock:разблокировать keychain'
    'doctor:проверить настройку'
    'help:справка'
  )
  local curcontext=$curcontext state line
  typeset -A opt_args
  _arguments -C '1: :->cmd' '*:: :->args' && return
  case $state in
    cmd) _describe -t commands 'команда' cmds ;;
    args)
      case $words[1] in
        add)
          _arguments \
            '-a[аккаунт/логин]:аккаунт' \
            '-n[заметка]:заметка' \
            '-f[сохранить файл]:файл:_files' \
            '(-u --update)'{-u,--update}'[заменить существующую запись]' \
            '1:имя записи:_sec_names'
          ;;
        get|cp|show) _arguments '1:имя записи:_sec_names' ;;
        rm) _arguments '(-y --yes)'{-y,--yes}'[без подтверждения]' '1:имя записи:_sec_names' ;;
        out) _arguments '(-f --force)'{-f,--force}'[перезаписать файл]' '1:имя записи:_sec_names' '2:путь:_files' ;;
        ls|pick) _arguments '-l[с датой создания]' '--tsv[вывод TSV]' '--pretty[таблица даже в pipe]' \
                   '--no-pager[без пейджера]' '1:префикс:_sec_names' ;;
        env) _arguments '-f[файл со списком VAR=имя]:файл:_files' '*::команда:_normal' ;;
        export) _arguments '-o[файл]:файл:_files' '--json[JSON в stdout]' ;;
        import) _arguments '1:файл:_files -g "*.(age|json)"' ;;
        init) _arguments '--attach[подключить существующий]' '--no-attach[не подключать]' ;;
        help) _describe -t commands 'команда' cmds ;;
      esac
      ;;
  esac
}
compdef _sec sec

# sl не заводим: это stern из conf.d/40-k8s.zsh, а 40-sec грузится позже и перекрыл бы его.
alias sc='sec cp'
