# ~/.config/zsh/.zshrc — только загрузчик.
# Вся конфигурация разложена по conf.d/, чтобы добавлять новое
# отдельными файлами, а не наращивать один длинный.

# --- Powerlevel10k instant prompt (должен остаться первым) ---
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# --- Oh-My-Zsh ---
export ZSH="$ZDOTDIR/oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git zsh-syntax-highlighting zsh-autosuggestions)
[[ -f "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# --- Powerlevel10k ---
[[ -f "$ZDOTDIR/.p10k.zsh" ]] && source "$ZDOTDIR/.p10k.zsh"

# --- Модули (по порядку номеров) ---
for _f in "$ZDOTDIR"/conf.d/[0-9]*.zsh(N); do source "$_f"; done
unset _f

# --- Машинно-специфичное и секреты (в git не попадает) ---
# Внутренние хосты, строки подключения, токены — сюда.
[[ -f "$ZDOTDIR/local.zsh" ]] && source "$ZDOTDIR/local.zsh"
