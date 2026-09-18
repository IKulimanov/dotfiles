# Точка входа. Всё то же самое делает ./install.sh, но по шагам.
SHELL := /usr/bin/env bash
HOME_DIR ?= $(HOME)
PACKAGES := zsh git nvim lazygit tig k9s
STOW := stow --no-folding --ignore='\.DS_Store' -t "$(HOME_DIR)"

.PHONY: help install check link unlink relink core apps macos lint identity

help:            ## показать эту справку
	@grep -E '^[a-z-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[1m%-10s\033[0m %s\n", $$1, $$2}'

install:         ## полная интерактивная установка
	@./install.sh

check:           ## проверить, что всё установлено и подключено
	@./install.sh --check

link:            ## подключить конфиги симлинками
	@$(STOW) $(PACKAGES)

relink:          ## пересоздать симлинки (после добавления файлов)
	@$(STOW) --restow $(PACKAGES)

unlink:          ## отключить конфиги
	@$(STOW) -D $(PACKAGES)

core:            ## поставить базовые пакеты
	@brew bundle --file=brew/Brewfile.core

apps:            ## поставить GUI-приложения
	@brew bundle --file=brew/Brewfile.apps

macos:           ## применить системные настройки macOS
	@./macos/defaults.sh

identity:        ## настроить git-идентичности заново
	@rm -f "$(HOME_DIR)/.config/git/identity" && ./install.sh

lint:            ## проверить синтаксис конфигов
	@if command -v shellcheck >/dev/null; then \
	  shellcheck install.sh macos/defaults.sh; \
	else \
	  echo "  (shellcheck не установлен, пропущен: brew install shellcheck)"; \
	fi
	@# bash 3.2 (системный на macOS) считает многобайтный символ частью имени
	@# переменной: "$$name…" ломается с unbound variable. Нужны фигурные скобки.
	@perl -ne 'print "$$ARGV:$$.: $$_" and $$bad=1 if /\$$\w+[^\x00-\x7F]/; \
	  END { exit 1 if $$bad }' install.sh macos/defaults.sh \
	  || { echo "  ↑ переменная перед не-ASCII символом: оберните в \$${}"; exit 1; }
	@zsh -n zsh/.zshenv zsh/.config/zsh/.zshrc zsh/.config/zsh/.zprofile
	@for f in zsh/.config/zsh/conf.d/*.zsh; do zsh -n "$$f"; done
	@git config -f git/.config/git/config --list >/dev/null
	@nvim --headless --clean -es +'lua assert(loadfile("nvim/.config/nvim/init.lua"))' +q
	@echo "OK"
