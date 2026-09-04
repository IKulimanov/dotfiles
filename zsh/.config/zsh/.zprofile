# ~/.config/zsh/.zprofile — читается для login-шеллов (каждая вкладка iTerm2).
#
# Homebrew должен идти В НАЧАЛЕ PATH, иначе /usr/bin/git (Apple, 2.39)
# перекрывает brew-версию. Делать это в .zshenv нельзя: после него macOS
# запускает /etc/zprofile → path_helper, который ставит системные пути
# вперёд. .zprofile читается уже после path_helper, поэтому порядок держится.
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [[ -x "$_brew" ]]; then eval "$("$_brew" shellenv)"; break; fi
done
unset _brew

# Свои бинарники — впереди всего (typeset -U из .zshenv убирает дубли)
path=("$HOME/bin" "$HOME/.local/bin" $path)
