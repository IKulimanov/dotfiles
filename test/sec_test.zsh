#!/usr/bin/env zsh
# Тесты для sec: временный keychain в $TMPDIR, без GUI и без буфера обмена.
# Запуск: make test  или  ./test/sec_test.zsh
emulate -L zsh
setopt pipefail

DOT=${0:A:h:h}
SEC=$DOT/sec/bin/sec
TMP=$(mktemp -d "${TMPDIR:-/tmp}/sec-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

export SEC_KEYCHAIN=$TMP/test.keychain-db
export SEC_PASSWORD=test-password
export XDG_CACHE_HOME=$TMP/cache
unset SEC_ACCOUNT SEC_AGE_RECIPIENT SEC_AGE_IDENTITY

typeset -i passed=0 failed=0
ok()  { passed+=1; print "  ok   $1" }
bad() { failed+=1; print "  FAIL $1: $2" }
assert_eq()      { [[ "$2" == "$3" ]] && ok "$1" || bad "$1" "ожидалось [$3], получено [$2]" }
assert_rc()      { (( $2 == $3 ))     && ok "$1" || bad "$1" "код $2, ожидался $3" }
assert_has()     { [[ "$2" == *"$3"* ]] && ok "$1" || bad "$1" "нет [$3] в [$2]" }
assert_not_has() { [[ "$2" != *"$3"* ]] && ok "$1" || bad "$1" "есть [$3] в [$2]" }
section() { print "\n$1" }

# чистый keychain перед группой тестов
fresh() {
  rm -f "$SEC_KEYCHAIN"
  "$SEC" init --no-attach >/dev/null 2>&1 || { print "не удалось создать тестовый keychain"; exit 1 }
}

section "1. init"
rm -f "$SEC_KEYCHAIN"
out=$("$SEC" init --no-attach 2>&1); rc=$?
assert_rc "init завершается успешно" $rc 0
[[ -f "$SEC_KEYCHAIN" ]] && ok "файл keychain создан" || bad "файл keychain создан" "нет $SEC_KEYCHAIN"
out=$("$SEC" init --no-attach 2>&1); rc=$?
assert_rc "повторный init падает" $rc 1
assert_has "повторный init объясняет причину" "$out" "уже существует"

section "2. add из stdin + get"
fresh
secret='p@ss "w\ord" пароль #1'
print -rn -- "$secret" | "$SEC" add pg-staging -n "хост db1, порт 5432" >/dev/null
got=$("$SEC" get pg-staging); rc=$?
assert_rc "get успешен" $rc 0
assert_eq "секрет со спецсимволами и кириллицей возвращается как есть" "$got" "$secret"
print 'abc' | "$SEC" add plain >/dev/null
assert_eq "перевод строки из stdin не попадает в секрет" "$("$SEC" get plain)" "abc"
print -rn -- 'deadbeef' | "$SEC" add hexlike >/dev/null
assert_eq "пароль, похожий на hex, не декодируется" "$("$SEC" get hexlike)" "deadbeef"

section "3. add -f + out"
fresh
head -c 3000 /dev/urandom > "$TMP/small.bin"
"$SEC" add -f "$TMP/small.bin" k8s/small >/dev/null
"$SEC" out k8s/small "$TMP/small.out" >/dev/null
cmp -s "$TMP/small.bin" "$TMP/small.out" && ok "бинарный файл (3 КБ) восстановлен байт в байт" \
  || bad "бинарный файл (3 КБ) восстановлен байт в байт" "содержимое отличается"
assert_eq "права на восстановленный файл 600" "$(stat -f %Lp "$TMP/small.out")" "600"
head -c 20000 /dev/urandom | base64 > "$TMP/big.txt"
"$SEC" add -f "$TMP/big.txt" k8s/big >/dev/null; rc=$?
assert_rc "большой файл (>4 КБ) сохраняется" $rc 0
"$SEC" out k8s/big "$TMP/big.out" >/dev/null
cmp -s "$TMP/big.txt" "$TMP/big.out" && ok "большой файл восстановлен байт в байт" \
  || bad "большой файл восстановлен байт в байт" "содержимое отличается"
printf 'line1\nline2\n' > "$TMP/text.txt"
"$SEC" add -f "$TMP/text.txt" k8s/text >/dev/null
"$SEC" out k8s/text "$TMP/text.out" >/dev/null
cmp -s "$TMP/text.txt" "$TMP/text.out" && ok "текстовый файл с переводами строк восстановлен" \
  || bad "текстовый файл с переводами строк восстановлен" "содержимое отличается"
out=$("$SEC" out k8s/text "$TMP/text.out" 2>&1); rc=$?
assert_rc "out не перезаписывает существующий файл без -f" $rc 1

section "4. повторный add"
fresh
print -rn a | "$SEC" add dup >/dev/null
out=$(print -rn b | "$SEC" add dup 2>&1); rc=$?
assert_rc "add существующего имени без -u падает" $rc 1
assert_has "add объясняет, что нужен -u" "$out" "-u"
assert_eq "значение не перезаписано" "$("$SEC" get dup)" "a"
print -rn b | "$SEC" add -u dup >/dev/null
assert_eq "add -u заменяет значение" "$("$SEC" get dup)" "b"

section "5. ls"
fresh
print -rn 'topsecret' | "$SEC" add pg-staging -a app -n "хост db1" >/dev/null
out=$("$SEC" ls)
assert_has "ls показывает имя" "$out" "pg-staging"
assert_has "ls показывает тип" "$out" "password"
assert_has "ls показывает аккаунт" "$out" "app"
assert_has "ls показывает заметку (кириллица)" "$out" "хост db1"
assert_not_has "ls не показывает секрет" "$out" "topsecret"
out=$("$SEC" show pg-staging)
assert_has "show показывает заметку" "$out" "хост db1"
assert_not_has "show не показывает секрет" "$out" "topsecret"

section "6. rm"
fresh
print -rn a | "$SEC" add gone >/dev/null
"$SEC" rm -y gone >/dev/null; rc=$?
assert_rc "rm успешен" $rc 0
out=$("$SEC" get gone 2>"$TMP/err"); rc=$?
assert_rc "get после rm падает с кодом 1" $rc 1
assert_eq "stdout пуст" "$out" ""
assert_has "stderr объясняет" "$(<"$TMP/err")" "не найдена"

section "7. env"
fresh
print -rn 'pgpass' | "$SEC" add pg-staging >/dev/null
print -rn 'ktoken' | "$SEC" add kafka/token >/dev/null
printf '# комментарий\nPGPASSWORD=pg-staging\n\nKAFKA_TOKEN=kafka/token\n' > "$TMP/.secrets"
got=$("$SEC" env -f "$TMP/.secrets" -- sh -c 'printf "%s|%s" "$PGPASSWORD" "$KAFKA_TOKEN"')
assert_eq "env подставляет переменные в дочернюю команду" "$got" "pgpass|ktoken"
[[ -z ${PGPASSWORD:-} ]] && ok "в родительском шелле переменной нет" || bad "в родительском шелле переменной нет" "PGPASSWORD задана"
out=$("$SEC" env -f "$TMP/.secrets" -- sh -c 'exit 7' 2>&1); rc=$?
assert_rc "env возвращает код команды" $rc 7

section "8. export / import"
fresh
print -rn 'pgpass' | "$SEC" add pg-staging -a app -n "хост db1" >/dev/null
head -c 5000 /dev/urandom > "$TMP/key.bin"
"$SEC" add -f "$TMP/key.bin" ssh/id_test >/dev/null
age-keygen -o "$TMP/age.key" 2>/dev/null
recipient=$(age-keygen -y "$TMP/age.key")
SEC_AGE_RECIPIENT=$recipient "$SEC" export -o "$TMP/backup.age" >/dev/null; rc=$?
assert_rc "export успешен" $rc 0
[[ -s "$TMP/backup.age" ]] && ok "файл экспорта создан" || bad "файл экспорта создан" "пустой или нет"
grep -q pgpass "$TMP/backup.age" && bad "экспорт зашифрован" "секрет виден открытым текстом" || ok "экспорт зашифрован"
before=$("$SEC" ls --tsv | sort)
export SEC_KEYCHAIN=$TMP/second.keychain-db
fresh
SEC_AGE_IDENTITY=$TMP/age.key "$SEC" import "$TMP/backup.age" >/dev/null; rc=$?
assert_rc "import успешен" $rc 0
after=$("$SEC" ls --tsv | sort)
assert_eq "ls после импорта совпадает (имя, тип, аккаунт, заметка)" "$(print -r -- "$after" | cut -f1-4)" "$(print -r -- "$before" | cut -f1-4)"
assert_eq "пароль после импорта совпадает" "$("$SEC" get pg-staging)" "pgpass"
"$SEC" out ssh/id_test "$TMP/key.out" >/dev/null
cmp -s "$TMP/key.bin" "$TMP/key.out" && ok "файл после импорта совпадает" || bad "файл после импорта совпадает" "содержимое отличается"
export SEC_KEYCHAIN=$TMP/test.keychain-db

section "9. get неизвестного имени"
fresh
out=$("$SEC" get nope 2>/dev/null); rc=$?
assert_rc "код 1" $rc 1
assert_eq "stdout пуст" "$out" ""

section "10. ls: префикс, группы, pipe"
fresh
for n in ssh/a ssh/b k8s/c plain; do print -rn x | "$SEC" add $n >/dev/null; done
assert_eq "ls PREFIX фильтрует по префиксу" "$("$SEC" ls ssh/ | cut -f1 | sort | tr '\n' ' ')" "ssh/a ssh/b "
assert_eq "ls pg фильтрует и без слэша" "$("$SEC" ls pl | cut -f1)" "plain"
out=$("$SEC" ls)
assert_not_has "в pipe нет цветовых кодов" "$out" $'\e['
assert_eq "в pipe четыре записи, по одной на строку" "$(print -r -- "$out" | wc -l | tr -d ' ')" "4"
out=$("$SEC" ls --pretty)
assert_has "pretty группирует ssh/" "$out" "ssh/ (2)"
assert_has "pretty группирует k8s/" "$out" "k8s/ (1)"
assert_has "pretty: записи без группы попадают в прочее" "$out" "прочее (1)"

section "11. help"
out=$("$SEC" help)
for c in init add get cp out ls show rm env export import lock unlock doctor pick; do
  assert_has "help упоминает $c" "$out" " $c"
done
out=$("$SEC" add --help)
assert_has "add --help содержит примеры" "$out" "Примеры"
out=$("$SEC" bogus 2>&1); rc=$?
assert_rc "неизвестная команда: код 2" $rc 2
assert_has "неизвестная команда: подсказка" "$out" "sec help"
out=$("$SEC" 2>&1 </dev/null); rc=$?
assert_has "sec без аргументов вне терминала печатает help" "$out" "Использование"

section "12. names и автодополнение"
fresh
for n in ssh/a ssh/b k8s/c; do print -rn x | "$SEC" add $n >/dev/null; done
assert_eq "names PREFIX" "$("$SEC" names ssh/ | sort | tr '\n' ' ')" "ssh/a ssh/b "
assert_eq "names без префикса — все" "$("$SEC" names | wc -l | tr -d ' ')" "3"
print -rn x | "$SEC" add ssh/new >/dev/null
assert_has "кэш имён сбрасывается после add" "$("$SEC" names)" "ssh/new"
comp=$(PATH="$DOT/sec/bin:$PATH" zsh -f -c '
  autoload -Uz compinit; compinit -D -u
  source "'"$DOT"'/sec/.config/zsh/conf.d/40-sec.zsh"
  print -r -- "${_comps[sec]}"')
assert_eq "40-sec.zsh регистрирует функцию дополнения" "$comp" "_sec"
zsh -n "$DOT/sec/.config/zsh/conf.d/40-sec.zsh" && ok "40-sec.zsh: синтаксис" || bad "40-sec.zsh: синтаксис" "zsh -n"
zsh -n "$SEC" && ok "sec: синтаксис" || bad "sec: синтаксис" "zsh -n"

print "\nИтого: $passed ok, $failed fail"
(( failed == 0 ))
