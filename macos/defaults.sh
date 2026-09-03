#!/usr/bin/env bash
# Системные настройки macOS. Запускается отдельно: ./macos/defaults.sh
# Всё обратимо — любую строку можно поменять и выполнить снова.
set -euo pipefail

echo "Настраиваю macOS…"

# ── Клавиатура ─────────────────────────────────────────────────
# Быстрый автоповтор: заметно при навигации hjkl в nvim.
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
# Долгое нажатие даёт повтор символа, а не меню с диакритикой
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
# Автозамены, которые ломают код и команды в терминале
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
# Tab по всем элементам диалогов, а не только по полям ввода
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# ── Finder ─────────────────────────────────────────────────────
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"   # список
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"   # искать в текущей папке
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
# Не создавать .DS_Store на сетевых дисках и флешках
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# ── Скриншоты ──────────────────────────────────────────────────
mkdir -p "$HOME/Pictures/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Pictures/Screenshots"
defaults write com.apple.screencapture disable-shadow -bool true
defaults write com.apple.screencapture type -string "png"

# ── Dock ───────────────────────────────────────────────────────
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.15
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock mru-spaces -bool false        # не переставлять Spaces
defaults write com.apple.dock tilesize -int 48

# ── Прочее ─────────────────────────────────────────────────────
# Не спрашивать «файл скачан из интернета» для каждого бинарника
defaults write com.apple.LaunchServices LSQuarantine -bool false
# Мгновенная анимация окон
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
# Сохранять в файл, а не в iCloud, по умолчанию
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
# Полный путь при печати ошибок в Терминале
defaults write com.apple.CrashReporter DialogType -string "none"

killall Finder Dock SystemUIServer 2>/dev/null || true
echo "Готово. Часть настроек применится после перезахода в систему."
