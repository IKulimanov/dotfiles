# Точка входа. Всё то же самое делает ./install.sh, но по шагам.
SHELL := /usr/bin/env bash
HOME_DIR ?= $(HOME)
PACKAGES := zsh git nvim

.PHONY: help install link unlink relink core apps macos lint identity

help:            ## показать эту справку
	@grep -E '^[a-z-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[1m%-10s\033[0m %s\n", $$1, $$2}'

install:         ## полная интерактивная установка
	@./install.sh

link:            ## подключить конфиги симлинками
	@stow --no-folding -t "$(HOME_DIR)" $(PACKAGES)

relink:          ## пересоздать симлинки (после добавления файлов)
	@stow --no-folding -t "$(HOME_DIR)" --restow $(PACKAGES)

unlink:          ## отключить конфиги
	@stow -D -t "$(HOME_DIR)" $(PACKAGES)

core:            ## поставить базовые пакеты
	@brew bundle --file=brew/Brewfile.core

apps:            ## поставить GUI-приложения
	@brew bundle --file=brew/Brewfile.apps

macos:           ## применить системные настройки macOS
	@./macos/defaults.sh

identity:        ## настроить git-идентичности заново
	@rm -f "$(HOME_DIR)/.config/git/identity" && ./install.sh

lint:            ## проверить синтаксис конфигов
	@shellcheck install.sh macos/defaults.sh
	@zsh -n zsh/.zshenv zsh/.config/zsh/.zshrc
	@for f in zsh/.config/zsh/conf.d/*.zsh; do zsh -n "$$f"; done
	@echo "OK"
