# Анализ репозитория dotfiles

Ревизия: коммит `a12527e`. Дата: 2026-09-03.

Оценка сделана с двумя фильтрами:

1. **Рабочий стек** — Java / Go / Kafka / Oracle / PostgreSQL / ClickHouse / Git / k8s / REST / Vue.js.
2. **Личное устройство** — конфиг должен обслуживать не только работу, но и личные проекты и бытовые задачи.

---

## TL;DR — что важно сделать в первую очередь

| # | Проблема | Где | Почему важно |
|---|---|---|---|
| 1 | Рабочий e-mail прописан в глобальный git-конфиг | `git/.config/git/config:3` | Каждый личный коммит уходит с корпоративным адресом. Прямое нарушение требования №2 |
| 2 | Nerd Font нигде не устанавливается, но конфиг его требует | `.p10k.zsh:122` + `Brewfile:27` | После чистой установки промпт и `eza --icons` — сломанные глифы |
| 3 | История zsh пишется внутрь git-репозитория | `.zshrc:44` | Из-за tree-folding в stow `~/.config/zsh` — симлинк в репо. История команд (токены, пароли в argv) лежит в рабочей копии git |
| 4 | LSP полностью выключен — все серверы закомментированы | `nvim/init.lua:114-117` | Neovim без автодополнения и переходов по коду. Для Java/Go это главный инструмент |
| 5 | Brewfile и install.sh дублируют список пакетов | `Brewfile` + `install.sh:52-80` | Два источника истины, разъедутся при первом же изменении |
| 6 | Нет менеджера версий для Java/Go/Node | `.zshrc:131` (только `rbenv`) | Основной стек не покрыт; Ruby, которого в стеке нет, — покрыт |
| 7 | На чистой машине `install.sh` молча не ставит ни одного пакета | `install.sh:26-34` | После установки Homebrew нет `eval "$(brew shellenv)"`, поэтому следующая же проверка `command -v brew` не проходит и все блоки установки пропускаются |

---

## Часть 1. Баги и проблемы в текущем конфиге

### P0 — исправить обязательно

#### 1.1. Глобальный git-конфиг подписывает всё рабочим адресом

`git/.config/git/config:2-3`

```ini
[user]
	name = Ivan K.
	email = work@example.com
```

Это глобальный конфиг → **любой** репозиторий на машине, включая личные и опенсорс, коммитится
с корпоративного адреса. Отменить это можно только вручную в каждом репо, и о забытом
`git config user.email` узнаёшь уже после push.

Правильное решение — условные включения по каталогу (`includeIf`, git ≥ 2.13). Личный адрес
делается дефолтом, рабочий подключается только внутри рабочего дерева:

```ini
# ~/.config/git/config
[user]
	name = Ivan K.
	email = personal@example.com        # дефолт — личный

[includeIf "gitdir:~/work/"]
	path = config.work                       # перекрывает user.email внутри ~/work/
[includeIf "gitdir:~/src/company/"]
	path = config.work
```

```ini
# ~/.config/git/config.work  (в репозиторий не коммитить — или коммитить без секретов)
[user]
	email = work@example.com
[commit]
	gpgsign = true
```

Важные детали: путь в `gitdir:` должен заканчиваться на `/`, чтобы покрыть подкаталоги;
`gitdir/i:` — регистронезависимый вариант. Есть также `includeIf "hasconfig:remote.*.url:..."`
— срабатывает по URL remote, а не по расположению каталога, что удобнее, если рабочие репо
разбросаны по диску.

Это же место — правильное для разделения SSH-ключей и подписи коммитов между личным и рабочим
контуром.

#### 1.2. Промпт требует Nerd Font, но шрифт не устанавливается

`.p10k.zsh:122` — `POWERLEVEL9K_MODE=nerdfont-v3`, то есть конфиг рассчитан на шрифт с
дополнительными глифами. При этом:

- в `Brewfile` из casks только `iterm2` и `docker` — шрифта нет;
- `install.sh` шрифт не ставит;
- `alias ls="eza --icons"` (`.zshrc:93`) тоже требует Nerd Font.

Обычно шрифт устанавливает мастер `p10k configure`, но здесь `.p10k.zsh` уже готовый и лежит в
репозитории — мастер не запускается, шрифт не появляется. Результат на чистой машине: вместо
иконок «крокозябры» или пустые квадраты.

Добавить в `Brewfile`:

```ruby
cask "font-meslo-lg-nerd-font"   # шрифт, под который сгенерирован .p10k.zsh
```

(с 2024 года шрифты живут в основном `homebrew/cask`, отдельный tap `homebrew/cask-fonts`
больше не нужен). И отдельным шагом — выставить шрифт в профиле iTerm2; это единственное, что
нельзя сделать из Brewfile, поэтому оно должно попасть в финальные инструкции `install.sh`.

#### 1.3. История zsh и локальные оверрайды пишутся в git-репозиторий

`.zshrc:44` — `HISTFILE="$ZDOTDIR/.zsh_history"`, где `ZDOTDIR=~/.config/zsh`.

GNU Stow по умолчанию использует *tree folding*: если целевого каталога нет, он создаёт симлинк
на каталог целиком, а не на каждый файл внутри. Значит `~/.config/zsh` становится симлинком на
`~/bin/dotfiles/zsh/.config/zsh`, и всё, что в него пишется, физически попадает в рабочую копию
git. Это уже осознано — в `.gitignore` есть строки для `.zsh_history` и `.zshrc.local` — но
подход лечит симптом, а не причину:

- история команд (а в ней `psql "postgres://user:pass@..."`, `curl -H "Authorization: Bearer ..."`,
  `kubectl create secret ...`) лежит в git-репозитории, который вы push-ите на GitHub;
- одна неосторожная правка `.gitignore` или `git add -f` — и она в публичной истории;
- `git status` в репо dotfiles шумит, а `stow --restow` спотыкается о посторонние файлы.

Два независимых исправления, нужны оба:

**(а)** унести состояние из конфигов по XDG:

```zsh
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
HISTFILE="$XDG_STATE_HOME/zsh/history"
mkdir -p "${HISTFILE:h}"
```

**(б)** отключить folding, чтобы каталоги были настоящими, а симлинками — только файлы:

```bash
stow --no-folding -d "$DOTFILES" -t "$HOME" --restow zsh
```

Без `(б)` любой инструмент, который решит что-то записать в `~/.config/git/` или
`~/.config/nvim/`, будет писать в репозиторий. Это касается и `p10k configure`, и
`nvim` (`:checkhealth` пишет логи), и `gh auth login`.

#### 1.4. Neovim: LSP присутствует, но не работает

`nvim/.config/nvim/init.lua:112-117`

```lua
local lspconfig = require("lspconfig")
-- Раскомментируй нужные серверы (установи через brew/npm/pip):
-- lspconfig.ts_ls.setup({})
-- lspconfig.pyright.setup({})
-- lspconfig.gopls.setup({})
-- lspconfig.lua_ls.setup({})
```

Все серверы закомментированы, поэтому `LspAttach` никогда не срабатывает и биндинги
`gd`/`gr`/`K`/`<leader>rn` не подключаются. Плюс **нет движка автодополнения вообще** —
ни `nvim-cmp`, ни `blink.cmp`. LSP без completion — это половина инструмента: подсказки типов
и импортов не появятся.

Отдельно: в списке нет ни одного сервера из вашего стека — нет `jdtls` (Java), нет Vue, нет
`yamlls` (а именно он даёт валидацию и автодополнение манифестов k8s по схемам).

Подробный разбор и конкретный набор — в разделе 3.3.

### P1 — стоит исправить

#### 1.5. Brewfile и install.sh — два списка пакетов

`Brewfile` описывает пакеты декларативно, а `install.sh:52-80` **повторяет те же имена
императивно**, вручную:

```bash
brew install gnu-stow bat eza ripgrep fd fzf zoxide jq htop tldr
brew install gh git-delta lazygit
brew install neovim direnv
brew install --cask iterm2 docker
```

Сейчас списки совпадают, но это ненадолго: добавите пакет в Brewfile — забудете в скрипте.
Причём именно Brewfile — тот файл, который «выглядит главным», а работает скрипт.

Решение — сделать Brewfile единственным источником и разбить его на группы, которые
`install.sh` предлагает по отдельности:

```
brew/Brewfile.core        # stow, bat, eza, fd, rg, fzf, zoxide, jq, btop...
brew/Brewfile.dev         # java/go/k8s/kafka/db/rest — рабочий стек
brew/Brewfile.personal    # медиа, бэкапы, заметки, финансы
brew/Brewfile.cask        # GUI
brew/Brewfile.mas         # App Store (через mas)
```

```bash
if ask "Установить базовые CLI-инструменты?"; then
  brew bundle --file="$DOTFILES/brew/Brewfile.core"
fi
```

Бонус: `brew bundle` идемпотентен, умеет `--no-upgrade`, а `brew bundle cleanup` покажет
пакеты, установленные руками и не описанные в конфиге. Плюс `brew bundle dump --describe`
поможет собрать текущее состояние машины в Brewfile.

#### 1.6. Нет менеджера версий для основного стека

`.zshrc:131`:

```zsh
command -v rbenv &>/dev/null && eval "$(rbenv init - zsh)"
```

Единственный подключённый менеджер версий — для Ruby, которого в стеке нет. При этом Java
(несколько JDK на разных проектах — почти неизбежно), Go и Node (для Vue) не покрыты.

Рекомендую **mise** (бывший rtx) — один инструмент вместо `sdkman` + `nvm` + `pyenv` + `jenv`:

```toml
# ~/.config/mise/config.toml — глобальные дефолты
[tools]
java = "temurin-21"
go = "1.23"
node = "22"
python = "3.12"
```

```toml
# в конкретном проекте: .mise.toml
[tools]
java = "temurin-17"     # legacy-сервис
```

Почему mise, а не sdkman/asdf:

- один бинарь на Java, Go, Node, Python, `kubectl`, `helm`, `terraform` — там же;
- переключает версии **по каталогу** автоматически, как direnv (и умеет заменить direnv:
  секция `[env]` в `.mise.toml`);
- на порядок быстрее asdf (нет shim-прослойки на каждый вызов), написан на Rust;
- понимает `.tool-versions` от asdf, `.nvmrc`, `.sdkmanrc` — миграция почти бесплатная.

Подключение в `.zshrc`: `command -v mise &>/dev/null && eval "$(mise activate zsh)"`.

Важно: `.p10k.zsh` уже знает про mise — `.mise.toml` есть в списке `anchor_files` (`:433`),
то есть каталог проекта не будет сокращаться в промпте.

Если хочется остаться ближе к экосистеме Java — альтернатива `sdkman`, но он покрывает только
JVM-мир (Java, Maven, Gradle, Kotlin, Scala) и требует отдельных инструментов для Go и Node.

#### 1.7. `SHARE_HISTORY` и `INC_APPEND_HISTORY` вместе — избыточно

`.zshrc:50-51`

```zsh
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY
```

`SHARE_HISTORY` включает в себя инкрементальную дозапись и вдобавок импортирует команды из
других сессий. Указывать оба смысла не имеет — второй флаг перекрывается первым.

Чего в наборе действительно **не хватает** и что важнее:

```zsh
setopt HIST_IGNORE_SPACE   # команда, начатая с пробела, не попадёт в историю
setopt EXTENDED_HISTORY    # писать timestamp и длительность
setopt HIST_VERIFY         # раскрыть !! для правки, а не выполнять сразу
```

`HIST_IGNORE_SPACE` — это то, чем набирают команды с секретом в аргументах:
` export ORACLE_PASSWORD=...` с ведущим пробелом не осядет в истории. С учётом раздела 1.3
это особенно уместно.

Отдельно стоит рассмотреть, нужен ли `SHARE_HISTORY` вообще: он смешивает историю всех
открытых вкладок, и Ctrl+R начинает выдавать команды из другого проекта. Многие предпочитают
`INC_APPEND_HISTORY_TIME` без шаринга. Вопрос вкуса, но выбор стоит сделать осознанно.

#### 1.8. `LC_ALL` не следует выставлять глобально

`.zshrc:125-126`

```zsh
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
```

`LC_ALL` — «кувалда»: она перекрывает **все** категории локали и делает невозможным частичное
переопределение (например, `LC_TIME` под свой формат даты или `LC_COLLATE=C` для
предсказуемой сортировки в скриптах). Стандартная рекомендация — задавать `LANG` и, при
необходимости, точечные `LC_*`, а `LC_ALL` оставлять для временного форсирования в конкретной
команде (`LC_ALL=C sort ...`).

Достаточно:

```zsh
export LANG=en_US.UTF-8
```

#### 1.9. `alias rm="rm -i"` — опасная привычка, а не защита

`.zshrc:99-101`

```zsh
alias rm="rm -i"
alias mv="mv -i"
alias cp="cp -i"
```

Проблема известная: интерактивный `rm` защищает ровно до того момента, когда он надоедает.
Дальше вырабатывается рефлекс писать `rm -rf` или `\rm`, а `-i` при `-f` игнорируется. Хуже
того, привычка «rm всегда спросит» ломается на любой чужой машине, в CI и в контейнере, где
алиаса нет — а рефлекс остался.

Более надёжный подход — не переопределять `rm`, а завести отдельную команду, которая
действительно обратима:

```ruby
brew "trash"     # macOS: перемещает в Корзину, а не удаляет
```

```zsh
alias rm="trash"     # обратимо
# настоящий rm остаётся доступен как \rm или /bin/rm
```

Так удаление по умолчанию восстановимо, а не «спрошено один раз».

### P2 — мелочи и шероховатости

#### 1.10. `setopt CORRECT` и git

`.zshrc:65`. Автокоррекция регулярно предлагает исправить нормальные вещи: подкомандные
конструкции (`git st` → `git status`), имена каталогов проектов, `kubectl` c флагами. С
`zsh-autosuggestions` + fzf-историей коррекция почти не нужна, а ложные срабатывания раздражают.
Как минимум стоит ограничить её командами, а не аргументами (`CORRECT` вместо `CORRECT_ALL`
— здесь уже так), либо отключить.

#### 1.11. Фоллбэк pager в git хрупкий

`git/.config/git/config:8,37`

```ini
pager = delta --dark 2>/dev/null || less
diffFilter = delta --color-only 2>/dev/null || cat
```

Конструкция рабочая (git прогоняет значение через `sh`), но с оговорками: `delta` уже
получил часть вывода в пайп до того, как `sh` вернул 127, и на больших диффах поведение
непредсказуемо. Плюс `--dark` в командной строке смешивает конфигурацию delta с git-конфигом,
хотя у delta есть свои ключи в `[delta]` — который здесь уже используется (`:39-42`).

Чище так:

```ini
[core]
	pager = delta
[delta]
	dark = true
	navigate = true
	side-by-side = true
	line-numbers = true
```

а сам `delta` считать обязательной зависимостью (он и так в `Brewfile`). Если фоллбэк всё же
нужен, надёжнее проверить наличие delta один раз в `install.sh` и записать нужный вариант в
`~/.config/git/config.local`.

#### 1.12. README советует шаг, который затрёт конфиг

`README.md`, «После установки», шаг 2: `p10k configure`.

Но `.p10k.zsh` (1843 строки) уже лежит в репозитории и подключается из `.zshrc:20`. Запуск
мастера **перезапишет** этот файл — а он, из-за folding (см. 1.3), находится в рабочей копии
git, так что вы получите большой незакоммиченный дифф и потеряете текущую тему.

Формулировку надо поменять: тема уже настроена, `p10k configure` — только если хочется
пересобрать её с нуля (и тогда изменения надо коммитить осознанно). Заодно в README не хватает
пункта про установку и выбор Nerd Font (см. 1.2), который сейчас не описан вообще.

#### 1.13. `install.sh` падает на существующих файлах

`install.sh:156` — `stow --restow "$pkg"` под `set -euo pipefail` (`:2`).

Если в `$HOME` уже есть настоящий `~/.zshenv` (а он есть почти всегда — его создаёт установщик
Oh-My-Zsh или сам пользователь), stow завершится с ошибкой «existing target is not owned by
stow», и из-за `set -e` скрипт оборвётся **посреди установки**, не дойдя до финальных
инструкций. Для «интерактивного установщика с подтверждениями» это плохой сценарий.

Нужно перед stow делать бэкап конфликтующих файлов:

```bash
backup_conflicts() {
  local pkg="$1" ts; ts="$(date +%Y%m%d-%H%M%S)"
  # stow сам перечислит конфликты в dry-run
  local conflicts
  conflicts="$(stow -n -d "$DOTFILES" -t "$HOME" --restow "$pkg" 2>&1 \
              | grep -oE '\* existing target is [^:]*: \S+' | awk '{print $NF}')" || true
  [[ -z "$conflicts" ]] && return 0
  mkdir -p "$HOME/.dotfiles-backup/$ts"
  while IFS= read -r f; do
    [[ -e "$HOME/$f" ]] || continue
    warn "бэкап $f → ~/.dotfiles-backup/$ts/"
    mkdir -p "$HOME/.dotfiles-backup/$ts/$(dirname "$f")"
    mv "$HOME/$f" "$HOME/.dotfiles-backup/$ts/$f"
  done <<< "$conflicts"
}
```

Общий принцип: `install.sh` должен быть безопасно перезапускаемым (идемпотентным) — сейчас он
почти такой, но конфликт stow это ломает.

#### 1.14. Мелкие замечания

- **`.zshrc:4`** — `export ZDOTDIR=...` дублирует `.zshenv:2`. Безвредно, но лишнее: к моменту
  чтения `.zshrc` переменная уже выставлена.
- **`.zshrc:120`** — `export PATH` в `.zshrc` действует только для интерактивных шеллов. GUI-
  приложения (в т.ч. IntelliJ IDEA, запущенная из Dock) его не увидят. Правильное место для
  `PATH` — `.zshenv`.
- **`~/bin/dotfiles`** — README предлагает клонировать репозиторий в `~/bin/dotfiles`, при этом
  `~/bin` добавлен в `PATH`. Смешивать «каталог исполняемых файлов» и «каталог с git-репо»
  неудобно. Логичнее `~/.dotfiles` или `~/src/dotfiles`, а `~/bin` оставить под собственные
  скрипты (см. 2.4).
- **`nvim/init.lua:55`** — `vim.uv` появился в Neovim 0.10 (в 0.9 это `vim.loop`). Раз конфиг
  ставится из Homebrew, версия будет свежая, но защитный вариант
  `(vim.uv or vim.loop).fs_stat(...)` стоит дешевле, чем отладка на машине с более старым nvim.
- **`git/.config/git/config:6`** — `autocrlf = input` на macOS/Linux безвреден, но точнее
  `core.autocrlf = false` + `.gitattributes` с `* text=auto eol=lf` в проектах: явные правила
  переносов на уровне репозитория вместо глобальной эвристики.
- **`git/.config/git/config:11`** — `defaultBranch = main`, тогда как сам этот репозиторий на
  `master`. Не баг, но стоит привести к одному виду.
- **`git/.config/git/config:52`** — `wip = !git add -A && git commit -m 'wip'`. `add -A`
  затянет в коммит всё, включая случайно созданный `.env` или дамп базы. С учётом раздела 5.3
  (gitleaks) риск снижается, но алиас всё равно стоит сделать аккуратнее.
- **`.zshrc:71`** — `source <(fzf --zsh 2>/dev/null) || true`: `||` относится к `source`, а не к
  `fzf`, поэтому при старой версии fzf (без `--zsh`, до 0.48) в шелл уйдёт пустая подстановка.
  Работает, но `if fzf --zsh >/dev/null 2>&1; then source <(fzf --zsh); fi` честнее.

---

## Часть 2. Архитектура репозитория

Сейчас структура плоская: три stow-пакета (`zsh`, `git`, `nvim`), `Brewfile`, `install.sh`.
Для текущего объёма это нормально, но она не масштабируется под две вещи, которые вам нужны:
**разделение work/personal** и **рост числа компонентов**.

### 2.1. Профили: работа и личное

Это ядро требования №2. Один и тот же репозиторий должен разворачиваться и на рабочей, и на
личной машине, и внутри одной машины разделять контуры. Предлагаю три уровня:

**Уровень 1 — git-идентичности по каталогу.** Через `includeIf` (см. 1.1). Личное — дефолт,
рабочее — по пути. Это решает 80% задачи и стоит 10 строк.

**Уровень 2 — профиль машины.** Файл `~/.config/dotfiles/profile` с одним словом
(`work` / `personal`), который создаёт `install.sh`, и ветвление по нему:

```zsh
DOTFILES_PROFILE="$(cat "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/profile" 2>/dev/null || echo personal)"
[[ -f "$ZDOTDIR/conf.d/profile.$DOTFILES_PROFILE.zsh" ]] && source "$ZDOTDIR/conf.d/profile.$DOTFILES_PROFILE.zsh"
```

Так рабочие алиасы (`kubectl` на прод-кластер, VPN, внутренние registry) не попадают на личный
ноутбук, а личные (медиа, бэкапы) — на рабочий.

**Уровень 3 — секреты вне git.** `.zshrc.local` уже есть (`.zshrc:134`) и это правильно, но он
не документирован толком и, как и история, живёт в репозитории (см. 1.3). Стоит вынести в
`~/.config/zsh/local/` за пределами stow-дерева и описать в README. Что туда идёт: внутренние
хосты, `JDBC`-строки, токены, корпоративные proxy.

### 2.2. Модульный `.zshrc`

Файл на 134 строки читаемый, но с добавлением k8s/kafka/db-алиасов и профилей он быстро
разрастётся. Классическая разбивка:

```
zsh/.config/zsh/
├── .zshrc                    # только загрузчик: 15 строк
├── .p10k.zsh
└── conf.d/
    ├── 00-options.zsh        # setopt, история, completion
    ├── 10-keybindings.zsh    # Option+Arrow и прочее
    ├── 20-tools.zsh          # fzf, zoxide, mise, direnv, atuin
    ├── 30-aliases.zsh        # общие алиасы
    ├── 40-k8s.zsh            # kubectl/helm/k9s + completion
    ├── 41-java.zsh           # maven/gradle
    ├── 42-db.zsh             # psql/clickhouse/sqlcl
    ├── 43-kafka.zsh          # kcat/kafkactl
    ├── profile.work.zsh
    └── profile.personal.zsh
```

```zsh
# .zshrc
for f in "$ZDOTDIR"/conf.d/[0-9]*.zsh; do source "$f"; done
```

Выигрыш не только в порядке: становится видно, что именно тормозит старт (`zsh -xv` по файлам),
и можно отключить один блок, не комментируя куски большого файла.

### 2.3. Скорость старта шелла

Oh-My-Zsh — заметная часть времени запуска (обычно 200-400 мс, зависит от числа плагинов).
Powerlevel10k instant prompt (`.zshrc:8-10`) маскирует это визуально — промпт появляется сразу
— но шелл всё равно не готов принимать команды, пока не догрузится.

Из текущего конфига OMZ используется очень скромно: плагины `git`, `direnv` и два внешних
(`zsh-autosuggestions`, `zsh-syntax-highlighting`). Всё это работает и без фреймворка:

- `git`-плагин OMZ — это в основном алиасы, а свои у вас уже есть (`.zshrc:104-107`);
- `direnv`-плагин — одна строка `eval "$(direnv hook zsh)"` (и она не нужна, если перейти
  на mise, см. 1.6);
- два оставшихся плагина ставятся любым менеджером.

Варианты, если старт начнёт мешать:

| Вариант | Плюсы | Минусы |
|---|---|---|
| Оставить OMZ, урезать плагины | ничего не менять | потолок ~150-250 мс |
| `sheldon` (Rust, декларативный TOML) | быстрый, конфиг в git, ленивая загрузка | ещё одна зависимость |
| `zinit` | самый быстрый, turbo-режим | сложный синтаксис |
| Без фреймворка + `zsh-defer` | минимум магии, полный контроль | всё руками |

Измерить, прежде чем чинить:

```bash
for i in {1..10}; do /usr/bin/time -p zsh -i -c exit; done 2>&1 | grep real
zsh -i -c 'zmodload zsh/zprof; exit' # либо zprof в начале .zshrc
```

Если старт < 200 мс — не трогать, это не проблема.

### 2.4. Чего в репозитории нет вообще

| Компонент | Зачем |
|---|---|
| `bin/` | Собственные скрипты. `~/bin` уже в `PATH` (`.zshrc:120`) — логично держать их здесь и стоу-ить |
| `macos/defaults.sh` | Системные настройки macOS через `defaults write`: скорость автоповтора клавиш, каталог скриншотов, показ расширений в Finder, отключение «естественной» прокрутки. Классическая и очень заметная часть dotfiles |
| `ssh/` | `~/.ssh/config` — хосты, jump-хосты, ключи. Один из самых полезных конфигов для инженера с k8s и БД. Сам конфиг коммитить можно, ключи — нет |
| `tmux/` | См. 4.6 — при работе через SSH сплиты iTerm2 не помогают |
| `.editorconfig` | Единые отступы для самого репозитория |
| CI | См. 2.5 |
| `LICENSE` | Публичный репозиторий без лицензии формально «все права защищены» |
| Поддержка Linux | Стек на k8s почти гарантирует Linux-машины. `install.sh` сейчас mac-only (Homebrew на Linux есть, но casks и `defaults` — нет) |

### 2.5. CI — проверка того, что конфиг не сломан

Сейчас ошибку в `install.sh` или `.zshrc` вы обнаружите только на живой машине при установке.
Дешёвая страховка — GitHub Actions:

```yaml
# .github/workflows/ci.yml
name: ci
on: [push, pull_request]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: shellcheck
        run: shellcheck install.sh
      - name: zsh syntax
        run: |
          sudo apt-get update && sudo apt-get install -y zsh
          zsh -n zsh/.config/zsh/.zshrc
          zsh -n zsh/.zshenv
      - name: lua syntax
        run: |
          sudo apt-get install -y lua5.1 luajit
          luajit -bl nvim/.config/nvim/init.lua >/dev/null
      - name: stow dry-run
        run: |
          sudo apt-get install -y stow
          stow -n -v --no-folding -t "$HOME" zsh git nvim
      - name: gitleaks
        uses: gitleaks/gitleaks-action@v2
```

`shellcheck` на `install.sh` почти наверняка найдёт замечания уже сейчас. `gitleaks` в CI —
страховка от того, что описано в 1.3: если история или токен всё-таки попадут в коммит, вы
узнаете об этом до push в публичный репозиторий.

Плюс `Makefile` или `justfile` как единая точка входа:

```make
install:   ; ./install.sh
link:      ; stow --no-folding -t $(HOME) zsh git nvim
unlink:    ; stow -D -t $(HOME) zsh git nvim
brew:      ; brew bundle --file=brew/Brewfile.core
lint:      ; shellcheck install.sh && zsh -n zsh/.config/zsh/.zshrc
update:    ; topgrade
```

---

## Часть 3. Разбор по компонентам

### 3.1. zsh

Что уже хорошо: XDG-раскладка через `ZDOTDIR`, instant prompt, аккуратные биндинги
Option+Arrow, `.zshrc.local` как escape hatch, все внешние инструменты подключаются через
`command -v` (конфиг не падает, если чего-то нет).

Проблемы разобраны в 1.3, 1.7-1.11. Что стоит **добавить**:

**Atuin** — замена Ctrl+R. История в SQLite вместо текстового файла: полнотекстовый поиск,
фильтр по каталогу/хосту/коду выхода, статистика. Опционально — end-to-end шифрованная
синхронизация между машинами (можно на своём сервере). Для двух машин (рабочая + личная) это
буквально то, что нужно: одна история команд везде. И решает 1.3 — база лежит в
`~/.local/share/atuin`, не в репозитории.

```zsh
command -v atuin &>/dev/null && eval "$(atuin init zsh)"
```

**Completion для основного стека.** Сейчас нет ни одного:

```zsh
# в conf.d/40-k8s.zsh
if command -v kubectl &>/dev/null; then
  source <(kubectl completion zsh)
  alias k=kubectl
  compdef k=kubectl                 # автодополнение работает и для алиаса
fi
command -v helm  &>/dev/null && source <(helm completion zsh)
command -v gh    &>/dev/null && eval "$(gh completion -s zsh)"
command -v mise  &>/dev/null && eval "$(mise completion zsh)"
```

Важно: генерация completion на каждый старт шелла — это несколько сотен миллисекунд. Лучше
кешировать в `~/.cache/zsh/completions/_kubectl` и обновлять по расписанию, либо использовать
`zsh-defer`.

**`fzf-tab`** — Tab-дополнение через fzf-интерфейс. Одно из самых заметных улучшений
эргономики: `kubectl get pod <Tab>`, `git checkout <Tab>`, `cd <Tab>` — всё с fuzzy-поиском и
превью. Работает поверх обычного zsh-completion.

**Полезные функции вместо алиасов.** Например, для k8s:

```zsh
# порт-форвард с выбором пода через fzf
kpf() {
  local pod
  pod=$(kubectl get pods -o name | fzf) || return
  kubectl port-forward "$pod" "${1:?укажи порт, напр. 8080:8080}"
}
# лог с выбором пода
klog() { kubectl logs -f "$(kubectl get pods -o name | fzf)"; }
```

**`FZF_DEFAULT_OPTS` с превью.** Сейчас (`.zshrc:73`) только геометрия. Стоит добавить превью
через `bat` — он уже в Brewfile, но нигде не используется:

```zsh
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always {}'"
export BAT_THEME="Catppuccin Mocha"     # согласовать с темой nvim
```

### 3.2. git

Один из самых сильных конфигов в репозитории: `rerere`, `zdiff3`, `histogram`, `colorMoved`,
`autoStash`, `autoSetupRemote`, `fetch.prune` — это осознанный набор, а не копипаста.
Замечания — в 1.1, 1.11, 1.14.

Что добавить, с прицелом на большие Java-репозитории и на разделение work/personal:

```ini
# ── Производительность на больших репо (монорепы на Java) ──
[core]
	fsmonitor = true            # демон слежения за ФС вместо обхода дерева
	untrackedCache = true       # кеш untracked-файлов
[feature]
	manyFiles = true            # включает index.version=4 и index.skipHash
[gc]
	writeCommitGraph = true
[maintenance]
	auto = false                # вместо этого: git maintenance start (через launchd)
```

`core.fsmonitor` — самый заметный из них: на репозитории с десятками тысяч файлов
`git status` ускоряется в разы. Для Java-проектов с `target/`, `build/` и генерённым кодом это
существенно.

```ini
# ── Подпись коммитов ──
[gpg]
	format = ssh                # проще GPG: подпись SSH-ключом
[user]
	signingkey = ~/.ssh/id_ed25519.pub
[commit]
	gpgsign = true
[tag]
	gpgsign = true
[gpg "ssh"]
	allowedSignersFile = ~/.config/git/allowed_signers
```

SSH-подпись (git ≥ 2.34) на порядок проще GPG: используется тот же ключ, которым вы уже
push-ите. GitHub показывает «Verified». Если пользуетесь 1Password — его SSH-агент умеет
подписывать коммиты, и приватный ключ не лежит на диске (см. 5.1).

```ini
# ── Диффы под ваш стек ──
[diff "java"]
	xfuncname = "^[ \t]*(([A-Za-z_$][A-Za-z_$0-9]*[ \t]+)+[A-Za-z_$][A-Za-z_$0-9]*[ \t]*\\(.*)$"
```

На самом деле руками это писать не нужно — у git есть **встроенные** drivers. Достаточно
глобального файла атрибутов:

```gitattributes
# git/.config/git/attributes  (+ [core] attributesfile = ~/.config/git/attributes)
*.java   diff=java
*.go      diff=golang
*.kt      diff=kotlin
*.vue     diff=html
*.html    diff=html
*.css     diff=css
*.md      diff=markdown
*.py      diff=python
*.sql     diff=sql
*.tf      diff=terraform
```

Эффект: в заголовке каждого хунка (`@@ ... @@ <здесь>`) git показывает имя метода/класса,
а не случайную строку. При ревью больших Java-диффов это заметно экономит время.

```ini
# ── Удобства ──
[column]
	ui = auto                   # git branch/status в колонки
[branch]
	sort = -committerdate       # свежие ветки сверху
[tag]
	sort = version:refname
[help]
	autocorrect = prompt
[rerere]
	autoUpdate = true           # не только помнить, но и применять
[push]
	followTags = true
[transfer]
	fsckobjects = true          # ловить битые объекты
[submodule]
	recurse = true
[log]
	date = iso
[blame]
	ignoreRevsFile = .git-blame-ignore-revs   # не шуметь коммитами форматирования
```

`blame.ignoreRevsFile` очень уместен, если в проекте когда-то прогоняли
`google-java-format`/`spotless` по всей кодовой базе: без него `git blame` показывает автора
переформатирования вместо автора логики.

Алиасы — набор хороший, стоит дополнить:

```ini
	# что я насобирал в ветке относительно main
	up = log --oneline --graph main..HEAD
	# ветки, которые уже влиты и можно чистить
	gone = "!git fetch -p && git branch -vv | awk '/: gone]/{print $1}'"
	cleanup = "!git fetch -p && git branch -vv | awk '/: gone]/{print $1}' | xargs -r git branch -D"
	# кто и сколько в этом файле
	who = shortlog -sne --
	# найти коммит по содержимому изменения
	pickaxe = log -S
	# что изменилось в конкретном коммите, по файлам
	files = show --stat --oneline
```

Отдельно стоит посмотреть на **`git-absorb`** — автоматически раскладывает исправления по тем
коммитам ветки, к которым они относятся (вместо ручного `rebase -i` + `fixup`). При рабочем
процессе с `pull.rebase = true` (`:14`) это экономит много времени.

И **`difftastic`** — структурный (AST-based) diff: показывает, что переехал блок кода, а не что
изменились 40 строк. Хорошо дополняет `delta` (не заменяет: delta красивее для обычного
чтения, difftastic умнее на рефакторингах).

```ini
[diff]
	external = difft            # либо алиасом: dft = -c diff.external=difft diff
```

### 3.3. Neovim

Конфиг аккуратный и минималистичный, `lazy.nvim` — правильный выбор. Но, как разобрано в 1.4,
в текущем виде он **не покрывает ваш стек**: нет ни completion, ни живого LSP, ни грамматик для
Java/SQL/Vue.

**Treesitter** (`init.lua:98-101`) — сейчас:

```lua
"lua", "javascript", "typescript", "python", "go",
"json", "yaml", "bash", "html", "css", "dockerfile",
```

Для Java/Go/k8s/Vue/SQL нужно как минимум добавить:

```lua
ensure_installed = {
  -- есть
  "lua", "javascript", "typescript", "python", "go",
  "json", "yaml", "bash", "html", "css", "dockerfile",
  -- ваш стек
  "java",          -- основной язык
  "xml",           -- pom.xml, Spring-конфиги, logback
  "properties",    -- application.properties
  "groovy",        -- build.gradle
  "kotlin",        -- build.gradle.kts, всё чаще и сервисы
  "sql",           -- Oracle / PG / ClickHouse
  "vue",           -- фронт
  "gomod", "gosum", "gowork",
  "proto",         -- gRPC/схемы, часто рядом с Kafka
  "hcl", "terraform",
  "helm",          -- чарты k8s
  -- инфраструктура редактора
  "markdown", "markdown_inline",
  "gitcommit", "git_rebase", "gitignore", "diff",
  "regex", "toml", "vim", "vimdoc", "query",
}
```

`gitcommit` + `diff` заметно улучшают работу с git прямо в редакторе, `xml` обязателен при
Maven.

**Completion.** Без него LSP наполовину бесполезен. Актуальный выбор — `blink.cmp` (быстрее,
проще в настройке) или проверенный `nvim-cmp`:

```lua
{
  "saghen/blink.cmp",
  version = "*",
  opts = {
    keymap = { preset = "default" },      -- <C-y> подтвердить, <C-space> меню
    sources = { default = { "lsp", "path", "snippets", "buffer" } },
    signature = { enabled = true },        -- подсказка параметров метода
  },
},
```

**LSP.** Вместо ручной установки серверов — `mason.nvim`, который скачивает их сам:

```lua
{
  "williamboman/mason.nvim",
  opts = {},
},
{
  "williamboman/mason-lspconfig.nvim",
  dependencies = { "neovim/nvim-lspconfig", "saghen/blink.cmp" },
  opts = {
    ensure_installed = {
      "gopls",           -- Go
      "jdtls",           -- Java (см. оговорку ниже)
      "vue_ls",          -- Vue 3
      "vtsls",           -- TS/JS под Vue
      "yamlls",          -- YAML + схемы k8s
      "helm_ls",         -- Helm-чарты
      "jsonls",
      "bashls",
      "dockerls",
      "sqlls",
      "lua_ls",
      "terraformls",
    },
  },
},
```

Оговорка по Java: `jdtls` через `lspconfig` работает, но плохо — Eclipse JDT требует
управления workspace, отдельных путей на проект и настройки debug/test-адаптеров. Для
серьёзной работы с Java берут **`nvim-java`** или **`nvim-jdtls`** (последний — от автора
`lazy.nvim`, конфигурируется через `ftplugin/java.lua`). Честный совет: если основной язык
Java, IntelliJ IDEA останется быстрее для рефакторингов и отладки — nvim в этом случае
инструмент для «всего остального» (Go, YAML, SQL, конфиги, git), и это нормальное разделение.

**YAML-схемы для k8s** — заметная вещь, если много манифестов:

```lua
{
  "b0o/schemastore.nvim",
},
-- в настройке yamlls:
settings = {
  yaml = {
    schemaStore = { enable = false, url = "" },
    schemas = require("schemastore").yaml.schemas({
      extra = {
        {
          name = "Kubernetes",
          url = "https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/master-standalone-strict/all.json",
          fileMatch = { "k8s/**/*.yaml", "manifests/**/*.yaml" },
        },
      },
    }),
  },
},
```

Даёт автодополнение полей манифеста и подсветку опечаток в `apiVersion`/`kind` до `kubectl apply`.

**Два плагина, которые точно попадают в ваш стек:**

`vim-dadbod` + `vim-dadbod-ui` — SQL-клиент внутри Neovim. Поддерживает PostgreSQL, Oracle,
ClickHouse (через HTTP-интерфейс), MySQL. Дерево баз/таблиц слева, буфер запроса, результат в
отдельном окне, история. Заменяет переключение в DBeaver для быстрых запросов:

```lua
{
  "kristijanhusak/vim-dadbod-ui",
  dependencies = {
    { "tpope/vim-dadbod", lazy = true },
    { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
  },
  cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection" },
  init = function()
    vim.g.db_ui_use_nerd_fonts = 1
    vim.g.db_ui_save_location = vim.fn.stdpath("data") .. "/db_ui"
  end,
},
```

Строки подключения держать **не в git**, а в переменных окружения (`$DATABASE_URL`) или в
`.zshrc.local` / 1Password (см. 5.1) — `dadbod` умеет читать из env.

`kulala.nvim` (или `rest.nvim`) — HTTP-клиент по `.http`-файлам прямо в редакторе. Для работы с
REST это заменяет Postman в 90% случаев, а главное — запросы лежат **в репозитории проекта**
рядом с кодом и версионируются:

```http
### получить заказ
GET https://api.example.com/orders/42
Authorization: Bearer {{token}}

### создать
POST https://api.example.com/orders
Content-Type: application/json

{ "sku": "ABC", "qty": 2 }
```

**Инфраструктура редактора**, которой не хватает и которая окупается сразу:

| Плагин | Что даёт |
|---|---|
| `folke/which-key.nvim` | Подсказка биндингов по `<leader>`. С растущим конфигом — необходимость |
| `stevearc/conform.nvim` | Форматирование: `google-java-format`, `gofmt`/`goimports`, `prettier`, `sql-formatter`. Format-on-save |
| `mfussenegger/nvim-lint` | Линтеры, которых нет в LSP: `golangci-lint`, `yamllint`, `hadolint` |
| `folke/trouble.nvim` | Список диагностик/ссылок отдельным окном вместо `:copen` |
| `nvim-lualine/lualine.nvim` | Статусбар: ветка, диагностика, LSP-прогресс |
| `stevearc/oil.nvim` | Файловый менеджер как обычный буфер — правишь каталог текстом |
| `mfussenegger/nvim-dap` + `leoluz/nvim-dap-go` | Отладчик. Для Go работает отлично, для Java — через `nvim-java` |
| `sindrets/diffview.nvim` | Полноценный git-diff/history viewer. Дополняет `gitsigns` |
| `folke/todo-comments.nvim` | Подсветка и поиск `TODO`/`FIXME`/`HACK` по проекту |
| `windwp/nvim-ts-autotag` | Автозакрытие HTML/Vue-тегов через treesitter |

**Опции**, которые стоит добавить к текущему набору (`init.lua:12-32` — он и так хороший):

```lua
vim.opt.colorcolumn = "120"          -- типичный лимит в Java-проектах
vim.opt.list = true                  -- показывать невидимые символы
vim.opt.listchars = { tab = "→ ", trail = "·", nbsp = "␣" }
vim.opt.confirm = true               -- спросить вместо ошибки при :q с изменениями
vim.opt.inccommand = "split"         -- превью результата :%s/
vim.opt.swapfile = false             -- есть undofile, swap только мешает
vim.opt.timeoutlen = 300             -- быстрее реакция which-key
vim.opt.completeopt = "menu,menuone,noselect"
```

Ещё две вещи: `checker = { enabled = false }` (`init.lua:145`) отключает проверку обновлений
плагинов — разумно, но тогда стоит завести привычку периодически делать `:Lazy sync`. И
`lazy-lock.json` (файл блокировки версий плагинов) **стоит коммитить** — иначе воспроизводимость
конфига между машинами теряется; сейчас его нет в репозитории.

### 3.4. Brewfile

Замечания — в 1.2 (шрифт) и 1.5 (дублирование). Плюс структурные:

- нет `mas` — приложения из App Store не описываются, хотя на личной машине их обычно немало;
- нет `tap` — понадобится для части инструментов;
- нет разделения на группы (см. 1.5);
- `cask "docker"` — Docker Desktop. Стоит осознать два момента: (1) в организациях выше
  определённого размера он требует платной лицензии; (2) на macOS он заметно тяжелее
  альтернатив. **OrbStack** (быстрее, экономнее по батарее, умеет ещё и Linux-машины) или
  **colima** (полностью открытый, `docker` + `kubernetes` одной командой) — обе лучше по
  ресурсам. Если Docker Desktop не нужен именно как GUI, замена окупается.

Полный предлагаемый состав — в части 4.

### 3.5. install.sh

Сильные стороны: пошаговые подтверждения, описание каждого пакета перед установкой, проверки
идемпотентности для OMZ и плагинов, аккуратный вывод. Это заметно лучше среднего
dotfiles-установщика.

Проблемы: 1.5 (дублирование списков), 1.13 (падение на конфликтах stow). Дополнительно:

- **нет `--no-folding`** (`:156`) — корень проблемы 1.3;
- **нет dry-run режима.** `./install.sh --dry-run` для «посмотреть, что произойдёт» —
  недорого и полезно;
- **нет неинтерактивного режима.** `./install.sh --yes` пригодится для новой машины и для CI;
- **нет проверки архитектуры.** Homebrew на Apple Silicon живёт в `/opt/homebrew`, на Intel — в
  `/usr/local`. После установки brew скрипт не делает `eval "$(brew shellenv)"`, поэтому на
  чистой машине последующие `brew install` в том же запуске не найдут `brew` в `PATH`
  (`:31` ставит brew, а `:34` проверяет `command -v brew` — и на свежей системе проверка не
  пройдёт, вся установка пакетов молча пропустится). Это, по сути, ещё один P1-баг:

```bash
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
```

- **нет шага «профиль машины»** (см. 2.1) — а именно он превращает репозиторий в
  «и рабочий, и личный»;
- **нет установки шрифта и напоминания выставить его в iTerm2** (см. 1.2);
- финальные инструкции (`:163-176`) хорошие, но их стоит дополнить пунктами про Nerd Font,
  `mise install` и git-идентичности.

---

## Часть 4. Инструменты под ваш стек

Ниже — то, чего в репозитории нет и что напрямую относится к Java/Go/Kafka/Oracle/PG/
ClickHouse/k8s/REST/Vue. Разбито по темам; ставить всё сразу не нужно — отмечены приоритеты:
**[!]** — взял бы в первую очередь, **[~]** — по ситуации.

### 4.1. Kubernetes

| Пакет | Что делает | |
|---|---|---|
| `kubectl` | Собственно клиент. Сейчас его нет ни в Brewfile, ни в install.sh | **[!]** |
| `k9s` | TUI для кластера: поды, логи, exec, события, ресурсы — в одном окне. Самый большой выигрыш по времени из всего списка | **[!]** |
| `kubectx` / `kubens` | Быстрое переключение контекста и namespace (с fzf). `p10k` уже показывает `kubecontext` в промпте (`.p10k.zsh:79`) — пара идеальная | **[!]** |
| `stern` | Хвост логов сразу из нескольких подов по regexp, с цветом по поду. Для отладки в проде незаменим | **[!]** |
| `helm` | Чарты | **[!]** |
| `kubecolor` | Раскрашивает вывод `kubectl` | **[~]** |
| `kustomize` | Оверлеи манифестов | **[~]** |
| `krew` | Менеджер плагинов kubectl (`kubectl neat`, `kubectl tree`, `kubectl df-pv`) | **[~]** |
| `dive` | Послойный анализ docker-образа — почему образ на 1.2 ГБ | **[~]** |
| `kubeconform` | Валидация манифестов по схемам до `apply`. Хорошо в pre-commit | **[~]** |
| `popeye` | Аудит кластера на типовые проблемы (лимиты, пробы, RBAC) | **[~]** |
| `argocd` | CLI, если GitOps на Argo | **[~]** |
| `kubeseal` | Sealed Secrets, если используются | **[~]** |
| `lazydocker` | TUI для docker/compose. Дополняет `dc` алиас (`.zshrc:110`) | **[~]** |

Алиасы и функции — в `conf.d/40-k8s.zsh` (см. 3.1). Минимум: `k`, `kgp`, `kgs`, `kd`, `kl`,
`kx`/`kn` для контекста, и обязательно completion с `compdef k=kubectl`.

Отдельно про безопасность: стоит завести `kubectl` так, чтобы случайный `delete` в прод-контексте
был затруднён. `kubectx` показывает текущий контекст, `p10k` — тоже, но для прода полезен
дополнительный барьер: например, покрасить контекст в красный
(`POWERLEVEL9K_KUBECONTEXT_PROD_FOREGROUND`) и завести отдельный `KUBECONFIG` на прод, который
подключается явно.

### 4.2. Kafka

| Пакет | Что делает | |
|---|---|---|
| `kcat` (ранее kafkacat) | «`netcat` для Kafka»: продюсер/консьюмер из терминала, метаданные, оффсеты. Базовый инструмент | **[!]** |
| `kaf` | Более человечный CLI: топики, группы, оффсеты, профили кластеров | **[!]** |
| `kafkactl` | Ещё один CLI, сильный в управлении (ACL, конфиги топиков), удобные профили окружений | **[~]** |
| `jq` | Уже есть. В связке `kcat -C -t topic | jq` — основной способ смотреть события | ✓ |
| `avro-tools` / `jsonschema` | Если Schema Registry и Avro/Protobuf | **[~]** |
| `redpanda` (`rpk`) | Локальный Kafka-совместимый брокер одним бинарём — быстрее поднять для тестов, чем Kafka в compose | **[~]** |
| `conduktor` / AKHQ | GUI, если нужно смотреть содержимое топиков глазами. AKHQ — self-hosted и бесплатный | **[~]** |

Полезная функция для `conf.d/43-kafka.zsh`:

```zsh
# посмотреть последние N сообщений топика человеческим JSON
ktail() {
  local topic="${1:?укажи топик}" n="${2:-10}"
  kcat -b "${KAFKA_BROKERS:?задай KAFKA_BROKERS}" -C -t "$topic" -o "-$n" -e -q | jq .
}
```

`KAFKA_BROKERS` — в `.zshrc.local` или профиль (см. 2.1), не в git.

### 4.3. Базы данных

| Пакет | Что делает | |
|---|---|---|
| `libpq` | Даёт `psql`, `pg_dump` без установки всего сервера PostgreSQL | **[!]** |
| `pgcli` | `psql` с автодополнением таблиц/колонок и подсветкой. Заметно приятнее | **[!]** |
| `clickhouse` | Официальный CLI ClickHouse (`clickhouse client`) | **[!]** |
| `dbeaver-community` (cask) | GUI, умеет Oracle + PG + ClickHouse одновременно — редкое сочетание | **[!]** |
| Oracle `sqlcl` | Современная замена `sqlplus` (в Homebrew есть в `instantclient` tap) | **[!]** |
| Oracle Instant Client | Нужен для JDBC/native-подключений | **[!]** |
| `usql` | Универсальный CLI ко всему сразу (PG, Oracle, ClickHouse, MySQL) — один синтаксис вместо трёх | **[~]** |
| `pgformatter` / `sql-formatter` | Форматирование SQL. Подключается в `conform.nvim` (см. 3.3) | **[~]** |
| `sqlfluff` | Линтер SQL | **[~]** |
| `atlas` / `flyway` / `liquibase` | Миграции схемы. Flyway/Liquibase — стандарт в Java-мире | **[~]** |

Плюс `vim-dadbod-ui` из 3.3 — для быстрых запросов без переключения контекста.

**Про секреты подключений.** Это то место, где чаще всего утекают креды. Не держите строки
подключения в конфиге и не набирайте пароль в argv (он попадёт в историю — см. 1.7). Варианты:
`~/.pgpass` (права 600), `PGSERVICEFILE` с именованными сервисами, или 1Password CLI:

```zsh
export PGPASSWORD="$(op read 'op://Work/postgres-prod/password')"
```

### 4.4. Java

| Пакет | Что делает | |
|---|---|---|
| `mise` (или `sdkman`) | Управление JDK. См. 1.6 | **[!]** |
| `maven` / `gradle` | Сборка (если не через mise) | **[!]** |
| `mvnd` | Maven Daemon — тот же Maven, но с прогретой JVM. На больших проектах сборка ускоряется существенно | **[!]** |
| `google-java-format` | Форматирование. В `conform.nvim` и pre-commit | **[~]** |
| `jbang` | Запуск одиночного `.java`-файла как скрипта, с зависимостями. Удобно для утилит и прототипов | **[~]** |
| `visualvm` | Профилирование JVM, анализ heap dump | **[~]** |
| `async-profiler` | Низкооверхедный профайлер, flame graphs. Стандарт для продовых проблем | **[~]** |
| `jd-gui` / `cfr` | Декомпилятор — когда надо посмотреть, что внутри чужого jar | **[~]** |
| `intellij-idea` (cask) | Для основной работы с Java, вероятно, останется главным инструментом | **[!]** |
| `checkstyle` / `spotbugs` | Статический анализ, если не через Maven-плагин | **[~]** |

Алиасы для `conf.d/41-java.zsh`:

```zsh
alias mci="mvn clean install"
alias mcp="mvn clean package"
alias mvnq="mvn -q -DskipTests"        # быстрая сборка без тестов
alias mdt="mvn dependency:tree"
alias gw="./gradlew"
# на каком JDK я сейчас
alias jv='java -version 2>&1 | head -1'
```

Стоит также включить `java_version` в промпте — сейчас сегмент закомментирован
(`.p10k.zsh:67`), а при работе с несколькими JDK видеть активную версию полезно.
То же для `go_version` (`.p10k.zsh:62`).

### 4.5. Go

| Пакет | Что делает | |
|---|---|---|
| `go` (через mise) | Сам тулчейн | **[!]** |
| `golangci-lint` | Мета-линтер, де-факто стандарт. В `nvim-lint` и в CI | **[!]** |
| `delve` (`dlv`) | Отладчик. Основа для `nvim-dap-go` | **[!]** |
| `gopls` | LSP (поставится через mason) | **[!]** |
| `goreleaser` | Сборка релизов и кросс-компиляция | **[~]** |
| `air` | Live-reload для Go-сервисов при разработке | **[~]** |
| `mockery` | Генерация моков | **[~]** |
| `gotestsum` | Читаемый вывод `go test` | **[~]** |
| `grpcurl` | `curl` для gRPC — если сервисы говорят по gRPC | **[!]** |
| `buf` | Линт и генерация protobuf | **[~]** |

### 4.6. REST / API / нагрузка

| Пакет | Что делает | |
|---|---|---|
| `xh` (или `httpie`) | Человеческий HTTP-клиент. `xh` на Rust, быстрее; синтаксис как у httpie | **[!]** |
| `curlie` | Синтаксис httpie поверх настоящего curl — все флаги curl остаются доступны | **[~]** |
| `hurl` | HTTP-запросы и **проверки** в текстовом файле. Фактически интеграционные тесты API в git, запускаются в CI | **[!]** |
| `grpcurl` | gRPC | **[!]** |
| `websocat` | WebSocket из терминала | **[~]** |
| `posting` | TUI-клиент (аналог Postman в терминале), коллекции в YAML — версионируются | **[~]** |
| `bruno` (cask) | GUI-клиент, коллекции в файлах и в git (в отличие от Postman с облаком) | **[~]** |
| `oha` | Нагрузочное тестирование с живым TUI-графиком | **[!]** |
| `k6` | Сценарное нагрузочное тестирование на JS | **[~]** |
| `vegeta` | Нагрузка с постоянным RPS, хорошие отчёты | **[~]** |
| `mitmproxy` | Перехват и разбор HTTP-трафика — когда непонятно, что реально уходит в сеть | **[~]** |

`hurl` заслуживает отдельного слова: это тот же `.http`-файл, но с секцией проверок, поэтому
одни и те же файлы работают и как «покликать API руками», и как smoke-тесты в пайплайне:

```hurl
GET https://api.example.com/health
HTTP 200
[Asserts]
jsonpath "$.status" == "UP"
duration < 500
```

### 4.7. Vue / фронтенд

| Пакет | Что делает | |
|---|---|---|
| `node` (через mise) | Рантайм | **[!]** |
| `pnpm` | Быстрее и экономнее npm по диску | **[!]** |
| `biome` | Линтер + форматтер в одном, на Rust; заметно быстрее ESLint+Prettier | **[~]** |
| `vue_ls` + `vtsls` | LSP (через mason, см. 3.3) | **[!]** |
| `bun` | Рантайм/раннер, если хочется быстрых скриптов | **[~]** |

### 4.8. Общий CLI — чего не хватает

Текущий набор (`bat`, `eza`, `fd`, `ripgrep`, `fzf`, `zoxide`, `jq`, `htop`, `tldr`) — хорошая
база. Дополнения, упорядоченные по практической пользе именно для бэкендера:

| Пакет | Что делает | |
|---|---|---|
| `tmux` | Сессии, которые выживают обрыв SSH. При работе с серверами и k8s это не «удобство», а необходимость: iTerm2-сплиты (`Brewfile:27`) при разрыве соединения теряются вместе с процессами. Альтернатива — `zellij` (проще из коробки, встроенные подсказки) | **[!]** |
| `yq` | То же, что jq, но для YAML. С k8s и Helm — постоянно | **[!]** |
| `btop` | Красивее и информативнее `htop` (который уже есть). Показывает диск, сеть, GPU | **[!]** |
| `lnav` | Навигатор по логам: понимает форматы, умеет SQL-запросы к логам, склеивает несколько файлов по времени. Для разбора инцидентов | **[!]** |
| `just` | Task-runner: `justfile` в проекте вместо накопления shell-скриптов и `make`-хаков | **[!]** |
| `watchexec` | Запуск команды при изменении файлов (тесты, пересборка) | **[!]** |
| `gitleaks` | Поиск секретов в коде и истории. С учётом 1.3 — обязателен, и в pre-commit, и в CI | **[!]** |
| `pre-commit` | Фреймворк git-хуков: gitleaks, форматтеры, линтеры до коммита | **[!]** |
| `jless` / `fx` | Интерактивный просмотр большого JSON (ответы API, дампы) | **[~]** |
| `gron` | Превращает JSON в grep-абельные строки. `gron big.json | grep id` — когда структура неизвестна | **[~]** |
| `dust` | `du` с наглядным деревом — «куда ушло место» | **[~]** |
| `duf` | `df` в читаемом виде | **[~]** |
| `procs` | `ps` с деревом и цветом | **[~]** |
| `sd` | Замена текста проще, чем `sed` (нормальные regex, без экранирования) | **[~]** |
| `hyperfine` | Бенчмарк команд со статистикой. Полезно и для замера старта zsh (см. 2.3) | **[~]** |
| `entr` | Проще `watchexec`, если нужен минимум | **[~]** |
| `yazi` | Файловый менеджер TUI на Rust, с превью | **[~]** |
| `glow` | Рендер Markdown в терминале — для чтения README и своих заметок | **[~]** |
| `difftastic` | Структурный diff (см. 3.2) | **[~]** |
| `git-absorb` | Автораскладка fixup-коммитов (см. 3.2) | **[!]** |
| `gitui` | TUI для git на Rust — быстрее `lazygit` на больших репозиториях (lazygit уже есть, это альтернатива) | **[~]** |
| `mas` | CLI для App Store — чтобы описать в Brewfile и GUI-приложения оттуда | **[~]** |
| `topgrade` | Обновляет всё сразу: brew, mise, nvim-плагины, OMZ, App Store, gem/npm. Одна команда вместо восьми | **[!]** |
| `age` / `sops` | Шифрование файлов с секретами — если захочется коммитить конфиги с чувствительными данными | **[~]** |
| `direnv` | Уже есть ✓ (но mise может его заменить, см. 1.6) | ✓ |

---

## Часть 5. Личное устройство

Это вторая половина требования, и в текущем репозитории она не покрыта: конфиг целиком
про разработку. Ниже — то, что делает его конфигом *машины*, а не только *рабочего места*.

### 5.1. Менеджер паролей как инфраструктура — самое полезное изменение

**1Password + CLI (`op`)** (или Bitwarden + `bw`, если предпочтительнее открытое решение)
закрывает сразу несколько задач, которые в репозитории сейчас решаются либо никак, либо
через `.zshrc.local`:

- **SSH-агент.** Приватные ключи не лежат на диске в открытом виде, подтверждение — по Touch ID.
  Работает и с git, и с серверами.
- **Подпись коммитов.** Тем же ключом (см. 3.2), без настройки GPG.
- **Секреты в окружении без хранения на диске.** Вместо `export ORACLE_PASSWORD=...` в
  `.zshrc.local`:

```zsh
# .env в проекте коммитится, значения подставляются из хранилища
DATABASE_URL=op://Work/postgres-prod/url
KAFKA_PASSWORD=op://Work/kafka/password
```

```bash
op run --env-file=.env -- ./gradlew bootRun
```

- **Разделение work/personal** на уровне хранилищ (Vaults) — та же логика, что у git-идентичностей
  из 1.1.
- Плюс обычная функция: пароли, 2FA-коды, лицензии, документы — то есть личная часть.

Это единственный пункт из всего документа, который одновременно повышает и безопасность
рабочего контура, и удобство личного.

### 5.2. Приложения — рабочая среда macOS

| Приложение | Зачем | |
|---|---|---|
| **Raycast** | Замена Spotlight: запуск, буфер обмена с историей, сниппеты, калькулятор/конвертер, управление окнами, свои скрипты, поиск по файлам. Одно приложение вместо четырёх. Самое заметное улучшение повседневной работы из списка | **[!]** |
| **AeroSpace** | Тайловый оконный менеджер (i3-подобный) для macOS. Если нравится раскладывать окна с клавиатуры — лучший из существующих. Проще альтернатива — **Rectangle** | **[!]** |
| **Karabiner-Elements** | Ремап клавиатуры. Классика: CapsLock → Escape (для nvim) или → Hyper-модификатор под глобальные хоткеи | **[!]** |
| **Espanso** | Текстовый экспандер: шаблоны коммитов, адреса, реквизиты, часто набираемые SQL/kubectl-команды. Кроссплатформенный, конфиг в YAML — версионируется в этом же репозитории | **[~]** |
| **iTerm2** | Уже есть ✓. Стоит рассмотреть **WezTerm** (конфиг на Lua — то есть в git, как nvim) или **Ghostty** (быстрее, нативнее) | ✓ |
| **Stats** | Мониторинг CPU/RAM/сети/температуры в меню-баре | **[~]** |
| **Maccy** | История буфера обмена (если не Raycast) | **[~]** |
| **Hidden Bar** | Скрыть лишние иконки в меню-баре | **[~]** |
| **AppCleaner** | Полное удаление приложений вместе с их файлами | **[~]** |
| **Keka** | Архиватор (rar, 7z) | **[~]** |
| **IINA** | Видеоплеер (нативнее VLC) | **[~]** |
| **Stretchly** | Напоминания о перерывах. При 8+ часах за терминалом — не лишнее | **[~]** |
| **Obsidian** | Заметки в обычных Markdown-файлах на диске. Для инженера удобно тем, что база — это git-репозиторий: рабочие заметки, решения проблем, черновики архитектуры, личное — всё версионируется и ищется через `rg`. Читается тем же `nvim` и `glow` | **[!]** |

### 5.3. Личные данные, бэкапы, быт

| Инструмент | Зачем | |
|---|---|---|
| `restic` | Инкрементальные шифрованные бэкапы в S3/B2/локально. Дополняет Time Machine: TM спасает от смерти диска, restic — от «удалил и не заметил месяц назад» и работает вне дома | **[!]** |
| `rclone` | Синхронизация с любым облаком (Google Drive, S3, Яндекс.Диск), в т.ч. монтирование как ФС | **[!]** |
| `syncthing` | P2P-синхронизация между своими устройствами без облака | **[~]** |
| `mackup` | Бэкап настроек приложений (тех, что не в dotfiles) | **[~]** |
| `yt-dlp` | Скачивание видео/аудио | **[~]** |
| `ffmpeg` | Конвертация медиа. Понадобится рано или поздно | **[!]** |
| `imagemagick` | Пакетная обработка изображений: ресайз, конвертация, метаданные | **[!]** |
| `exiftool` | Метаданные фото — в т.ч. **удалить геолокацию** перед публикацией | **[~]** |
| `pandoc` | Конвертация документов (Markdown → PDF/DOCX). Для личных документов и резюме | **[~]** |
| `qrencode` | Генерация QR — Wi-Fi для гостей, ссылки | **[~]** |
| `hledger` | Учёт личных финансов в plain-text: файл в git, отчёты командой. Инженерный подход к бюджету, без подписок и без отдачи данных в чужое приложение | **[~]** |
| `taskwarrior` | Задачи из терминала. `p10k` уже умеет показывать счётчик задач в промпте (`.p10k.zsh` — сегменты `taskwarrior` и `todo` **включены**, но сами инструменты не установлены) | **[~]** |
| `timewarrior` | Учёт времени. Сегмент в промпте тоже уже включён | **[~]** |

Отдельно стоит отметить: в `.p10k.zsh` включены сегменты `todo`, `taskwarrior`,
`timewarrior`, `nordvpn`, `ranger`, `nnn`, `lf`, `xplr`, `yazi`, `chezmoi_shell`,
`nix_shell`, `midnight_commander` и десятки версий языков (`rvm`, `fvm`, `luaenv`, `plenv`,
`perlbrew`, `phpenv`, `scalaenv`, `haskell_stack`). Ничего из этого не установлено. На
производительность это влияет слабо (p10k проверяет наличие быстро), но список стоит
почистить под реальный набор инструментов — заодно станет понятнее, что промпт вообще может
показать. Оставить: `kubecontext`, `direnv`/`mise`, `java_version`, `go_version`, `node_version`,
`aws`, `terraform`, `context`, `time`, `command_execution_time`, `status`.

### 5.4. Настройки macOS в коде

Ни одной системной настройки в репозитории нет, а это самая заметная часть «нового ноутбука за
20 минут». Файл `macos/defaults.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# ── Клавиатура: быстрый автоповтор (критично для vim-навигации) ──
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
# Отключить замену кавычек и автокапитализацию — мешают в коде и терминале
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
# Полная навигация с клавиатуры (Tab по всем элементам диалогов)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# ── Finder ──
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"     # список
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"     # искать в текущей папке
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true  # без .DS_Store на сетевых

# ── Скриншоты ──
mkdir -p "$HOME/Pictures/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Pictures/Screenshots"
defaults write com.apple.screencapture disable-shadow -bool true
defaults write com.apple.screencapture type -string "png"

# ── Dock ──
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock mru-spaces -bool false      # не переставлять Spaces

# ── Прочее ──
defaults write com.apple.LaunchServices LSQuarantine -bool false   # без "скачано из интернета"
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

killall Finder Dock SystemUIServer 2>/dev/null || true
```

Такой файл окупается один раз при переезде на новую машину и второй раз — когда через год
забываешь, как отключить автозамену кавычек.

### 5.5. SSH-конфиг

Каталог `ssh/.ssh/config` — один из самых практичных конфигов при работе с серверами и k8s.
Коммитить можно сам `config` (без ключей), внутренние хосты — через `Include`:

```sshconfig
# ~/.ssh/config
Include ~/.ssh/config.work        # не в git — внутренние хосты
Include ~/.ssh/config.personal

Host *
    AddKeysToAgent yes
    UseKeychain yes               # macOS: пароль ключа в Keychain
    ServerAliveInterval 60        # не рвать соединение простоем
    ServerAliveCountMax 3
    ControlMaster auto            # переиспользовать соединение — быстрее git/scp
    ControlPath ~/.ssh/control/%C
    ControlPersist 10m
    IdentitiesOnly yes
    Compression yes

Host github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
```

`ControlMaster` заметно ускоряет повторные `git fetch` и `scp` к одному хосту;
`ServerAliveInterval` избавляет от отваливающихся SSH-сессий (в паре с tmux из 4.8 — рабочий
процесс перестаёт зависеть от качества сети).

Каталог `~/.ssh/control` надо создать заранее, иначе `ControlPath` не сработает.

---

## Часть 6. Роадмап

Порядок подобран так, чтобы каждый этап был законченным и не зависел от следующих.

### Этап 1 — исправить то, что сломано (полчаса)

1. `includeIf` для git-идентичностей: личный e-mail дефолтом, рабочий по каталогу (1.1)
2. `cask "font-meslo-lg-nerd-font"` в Brewfile + шаг в install.sh и README (1.2)
3. `HISTFILE` в `$XDG_STATE_HOME` + `stow --no-folding` (1.3)
4. `eval "$(brew shellenv)"` после установки Homebrew в install.sh (3.5)
5. Бэкап конфликтующих файлов перед stow (1.13)
6. Убрать `LC_ALL`, убрать дублирующий `INC_APPEND_HISTORY`, добавить `HIST_IGNORE_SPACE` (1.7, 1.8)
7. Поправить README: `p10k configure` затирает конфиг, добавить пункт про шрифт (1.12)

### Этап 2 — фундамент (вечер)

1. `install.sh` читает Brewfile через `brew bundle`; Brewfile разбит на `core`/`dev`/`personal`/`cask` (1.5)
2. `mise` вместо `rbenv`, глобальные версии Java/Go/Node (1.6)
3. Профиль машины work/personal + модульный `conf.d/` (2.1, 2.2)
4. `Makefile`/`justfile` как точка входа (2.5)
5. CI: shellcheck + `zsh -n` + stow dry-run + gitleaks (2.5)
6. `.editorconfig`, `LICENSE`, `lazy-lock.json` в git

### Этап 3 — рабочий стек (вечер)

1. k8s: `kubectl`, `k9s`, `kubectx`, `stern`, `helm` + completion + `conf.d/40-k8s.zsh` (4.1)
2. Neovim: mason + blink.cmp + живые LSP (gopls, vue_ls, yamlls) + расширенный treesitter (3.3)
3. `vim-dadbod-ui` и `kulala.nvim` — SQL и REST внутри редактора (3.3)
4. БД: `libpq`, `pgcli`, `clickhouse`, Oracle Instant Client, DBeaver (4.3)
5. Kafka: `kcat`, `kaf` + `conf.d/43-kafka.zsh` (4.2)
6. REST: `xh`, `hurl`, `grpcurl`, `oha` (4.6)
7. Java/Go: `mvnd`, `golangci-lint`, `delve` + алиасы (4.4, 4.5)
8. git: `fsmonitor`, SSH-подпись, глобальный `attributes` с `diff=java`/`diff=golang` (3.2)
9. `tmux` + конфиг (4.8)

### Этап 4 — личное и удобство (вечер)

1. 1Password + `op`: SSH-агент, подпись коммитов, секреты через `op run` (5.1)
2. Raycast, Karabiner (CapsLock → Escape), AeroSpace/Rectangle (5.2)
3. `macos/defaults.sh` (5.4)
4. `ssh/.ssh/config` с `ControlMaster` и `Include` (5.5)
5. Obsidian + git-репозиторий заметок (5.2)
6. `restic` + `rclone`: бэкап личных данных по расписанию (5.3)
7. `atuin` — единая история между машинами (3.1)
8. `topgrade` — обновление всего одной командой (4.8)
9. Почистить сегменты `.p10k.zsh` под реальный набор инструментов, включить `java_version`/`go_version` (5.3)

### Этап 5 — по желанию

1. `gitleaks` + `pre-commit` в шаблоне новых проектов (4.8)
2. `hledger` для личных финансов (5.3)
3. Поддержка Linux в `install.sh` (2.4)
4. Замер и оптимизация старта zsh; при необходимости — уход с Oh-My-Zsh (2.3)
5. `Espanso` с шаблонами команд и текстов (5.2)
6. `bin/` со своими скриптами (2.4)

---

## Приложение: что в репозитории уже сделано хорошо

Чтобы список замечаний не создавал ложного впечатления — сильные стороны, которые стоит
сохранить при рефакторинге:

- **XDG-раскладка через `ZDOTDIR`** — `$HOME` не засоряется, редкость для dotfiles
- **stow вместо самописных симлинков** — компоненты ставятся независимо
- **Защитные проверки `command -v` перед каждым `eval`** — конфиг не падает на машине без fzf/zoxide
- **`install.sh` с описанием каждого пакета перед установкой** — заметно лучше `curl | bash`
- **git-конфиг**: `rerere`, `zdiff3`, `histogram`, `colorMoved`, `autoStash`, `fetch.prune` —
  осознанный набор, а не копипаста из статьи
- **`.zshrc.local` как escape hatch** — правильный паттерн для секретов и машинно-специфичного
- **`lazy.nvim` с ленивой загрузкой по `keys`** — Telescope грузится только при первом использовании
- **Комментарии на русском по делу** — конфиг понятен через год
- **README с реальными командами и разделом «что внутри»** — большинство dotfiles-репозиториев
  документированы хуже
