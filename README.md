# dotfiles

Конфиги для macOS. Управляются через [GNU Stow](https://www.gnu.org/software/stow/) — каждый компонент ставится отдельно симлинками.

## Структура

```
zsh/           shell: Oh-My-Zsh, Powerlevel10k, fzf, zoxide, навигация Option+Arrow
git/           config, алиасы, delta (side-by-side диффы), глобальный gitignore
nvim/          lazy.nvim, telescope, treesitter, LSP, gitsigns
Brewfile       все brew-пакеты с описаниями
install.sh     интерактивный установщик (каждый шаг — с подтверждением)
```

## Установка

```bash
git clone https://github.com/IKulimanov/dotfiles.git ~/bin/dotfiles
cd ~/bin/dotfiles
./install.sh
```

Скрипт спросит что ставить. Можно ставить выборочно.

## Ручная установка

Без скрипта — через stow напрямую:

```bash
brew install gnu-stow
cd ~/bin/dotfiles
stow zsh    # ~/.zshenv + ~/.config/zsh/
stow git    # ~/.config/git/
stow nvim   # ~/.config/nvim/
```

## После установки

1. Перезапустить терминал или `exec zsh`
2. Настроить тему: `p10k configure`
3. iTerm2 → Preferences → Profiles → Keys → Left Option key = **Esc+** (для Option+Arrow навигации)

## Что внутри

### zsh

- **Option+Left/Right** — перемещение по словам
- **Option+Backspace** — удаление слова
- **Ctrl+R** — fuzzy-поиск по истории (fzf)
- **Ctrl+T** — fuzzy-поиск файлов
- **z dirname** — переход в каталог по частичному имени (zoxide)
- Алиасы: `ls`→eza, `gs`→git status, `gl`→git log, `dc`→docker compose
- Локальные настройки: `~/.config/zsh/.zshrc.local` (не в git)

### git

- `pull.rebase = true` — без лишних merge-коммитов
- `push.autoSetupRemote` — push без `-u`
- `rerere` — запоминает решения конфликтов
- delta — подсветка диффов, side-by-side
- Алиасы: `lg`, `undo`, `wip`, `amend`, `branches`
- Глобальный ignore: .DS_Store, .env, node_modules, \_\_pycache\_\_, .idea

### nvim

- `Space+f` — поиск файлов, `Space+g` — grep, `Space+b` — буферы
- Treesitter — подсветка для js/ts/python/go/lua/bash/json/yaml/html/css/dockerfile
- LSP — серверы раскомментировать в `init.lua` по необходимости
- gitsigns, auto-pairs, комментирование (`gcc`)

### Brewfile

```bash
# посмотреть что будет установлено
cat Brewfile

# установить всё
brew bundle

# установить конкретный пакет
brew install fzf
```
