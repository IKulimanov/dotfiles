# ===============================
#  ~/.zshrc  •  Clean, readable
# ===============================

# --- Powerlevel10k instant prompt (keep at top) ---
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# --- Oh‑My‑Zsh root & theme ---
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# --- Plugins (add here as needed) ---
plugins=(
  git
  zsh-syntax-highlighting
  zsh-autosuggestions
)

# --- Load Oh‑My‑Zsh ---
source "$ZSH/oh-my-zsh.sh"

# --- Prompt tune‑up (p10k) ---
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# --- Languages / SDKs ---
eval "$(rbenv init - zsh)"

# --- Aliases ---
alias ls='colorls'         # colourful ls
# add more aliases or functions in $ZSH_CUSTOM/*.zsh

# --- Path tweaks (prepend personal bin) ---
export PATH="$HOME/bin:$PATH"

# --- Environment defaults ---
export LANG=en_US.UTF-8

# End of file
