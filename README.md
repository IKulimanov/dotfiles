# dotfiles

Конфиги для macOS. Ставятся через [GNU Stow](https://www.gnu.org/software/stow/) — каждый компонент отдельно, симлинками.

**Личных данных в репозитории нет.** Имя и почта для git спрашиваются при установке и сохраняются вне git — см. [Идентичности git](#идентичности-git).

## Структура

```
zsh/            шелл: Oh-My-Zsh, Powerlevel10k, fzf, zoxide, модули в conf.d/
git/            настройки, алиасы, delta, глобальный ignore (без имени и почты)
nvim/           YAML/k8s, Markdown, логи, Go — LSP, автодополнение, форматирование
brew/           Brewfile.core (CLI) и Brewfile.apps (GUI)
macos/          системные настройки через defaults write
install.sh      интерактивный установщик, каждый шаг с подтверждением
Makefile        отдельные операции: make link, make lint, make identity
docs/           ANALYSIS.md — разбор конфига, ROADMAP.md — что дальше
```

## Установка

```bash
git clone https://github.com/IKulimanov/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

Скрипт спрашивает про каждый шаг — можно ставить выборочно и запускать повторно.
Существующие файлы в `$HOME` не затираются: они уезжают в `~/.dotfiles-backup/<дата>/`.

```bash
./install.sh --dry-run    # показать, что будет сделано, ничего не меняя
./install.sh --yes        # без вопросов, для новой машины
```

### Вручную, без скрипта

```bash
brew bundle --file=brew/Brewfile.core
make link          # stow --no-folding -t ~ zsh git nvim
```

`--no-folding` здесь принципиален. Без него stow подменяет **каталог** `~/.config/zsh`
симлинком на репозиторий, и всё, что туда пишется — история команд, кеши, Oh-My-Zsh —
оказывается в рабочей копии git. С флагом каталоги остаются настоящими, а симлинками
становятся только файлы.

## Идентичности git

Имя и почта не хранятся в репозитории. `install.sh` создаёт `~/.config/git/identity`
(права 600, в git не попадает), а отслеживаемый `git/.config/git/config` его подключает.

По умолчанию используется **личная** почта. Рабочие аккаунты привязываются к каталогу:
всё, что лежит внутри указанного пути, подписывается своей почтой автоматически.

```
~/proj/pet-project     → личная почта
~/work/service-a       → рабочая почта
~/work/service-b       → рабочая почта
```

Что получается на диске:

```ini
# ~/.config/git/identity            (личная — действует везде по умолчанию)
[user]
	name  = Имя Фамилия
	email = personal@example.com

[includeIf "gitdir:~/work/"]        # всё внутри ~/work/ — рабочее
	path = ~/.config/git/identity.work
```

```ini
# ~/.config/git/identity.work
[user]
	email = work@example.com
```

Аккаунтов можно завести сколько угодно — установщик спрашивает про каждый следующий.
Перенастроить в любой момент:

```bash
make identity
```

Проверить, какая идентичность действует в текущем репозитории:

```bash
git whoami        # → Имя Фамилия <work@example.com>
```

## После установки

1. `exec zsh`
2. iTerm2 → Settings → Profiles:
   - **Text → Font** → `MesloLGS NF` — обязательно, иначе промпт рисует квадраты
   - **Keys → Left Option key** → `Esc+` — для навигации Option+Стрелки
3. `git whoami` в рабочем и в личном репозитории — убедиться, что почты разные
4. Первый запуск `nvim` сам поставит плагины и LSP-серверы

## Что внутри

### zsh

Конфигурация разложена по `conf.d/`, `.zshrc` — только загрузчик.

| | |
|---|---|
| `Ctrl+R` | fuzzy-поиск по истории |
| `Ctrl+T` | поиск файлов (превью через bat) |
| `Alt+C` | переход в каталог (превью дерева) |
| `Option+←/→` | перемещение по словам |
| `↑`/`↓` | поиск по истории с учётом набранного префикса |
| `z <имя>` | умный cd (zoxide) |

- История — в `~/.local/state/zsh/history`, **не** в репозитории
- `HIST_IGNORE_SPACE`: команда, начатая с пробела, в историю не попадёт — так набирают строки с паролями
- `rm` → `trash` (удаление в Корзину, обратимо). Настоящий `rm` доступен как `\rm`
- Локальные настройки и секреты: `~/.config/zsh/local.zsh` (в git не попадает)

### git

`pull.rebase`, `push.autoSetupRemote`, `rerere` с автоприменением, `zdiff3`,
`histogram`, `colorMoved`, `fetch.prune`, delta с side-by-side диффами.

Алиасы: `lg`, `up` (что накопилось относительно main), `undo`, `wip`, `amend`,
`gone` (ветки с удалённым upstream), `who`, `pickaxe`, `whoami`.

### nvim

Профиль осознанно узкий: **YAML/k8s, документация, логи, Go, личные проекты**.
Java здесь не поддерживается — для неё IDEA.

| | |
|---|---|
| `Space+f` / `Space+g` / `Space+b` | файлы / поиск по содержимому / буферы |
| `Space+d` | диагностика проекта |
| `-` | файловый менеджер в текущем каталоге (oil) |
| `Space+gd` / `Space+gh` | diff рабочего дерева / история файла |
| `Space+tw` | перенос длинных строк — для логов |
| `:Tail` | следить за растущим файлом, как `tail -f` |
| `gd` / `gr` / `K` | определение / ссылки / документация (LSP) |

- LSP: `gopls`, `yamlls`, `jsonls`, `bashls`, `dockerls`, `marksman`, `taplo`, `lua_ls` — ставятся автоматически через mason
- YAML со схемами: автодополнение и валидация манифестов k8s, docker-compose, GitHub Actions
- Автодополнение — `blink.cmp`; форматирование — `conform.nvim` (для Go по сохранению)
- Файлы больше 5 МБ открываются без подсветки, чтобы nvim не подвисал на логах

### brew

```bash
brew bundle --file=brew/Brewfile.core   # CLI
brew bundle --file=brew/Brewfile.apps   # GUI
```

### macos

```bash
./macos/defaults.sh
```

Автоповтор клавиш, отключение автозамены кавычек, показ расширений и скрытых файлов
в Finder, отдельный каталог для скриншотов, поведение Dock. Всё обратимо.

## Дальше

`docs/ROADMAP.md` — что сделано, что решено и что осталось.
`docs/ANALYSIS.md` — подробный разбор конфига, из которого выросли эти изменения.
