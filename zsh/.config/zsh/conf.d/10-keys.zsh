# Навигация по словам. Требует в iTerm2:
#   Preferences → Profiles → Keys → Left Option key = Esc+
bindkey "^[[1;3D" backward-word        # Option+Left
bindkey "^[[1;3C" forward-word         # Option+Right
bindkey "^[^?"    backward-kill-word   # Option+Backspace
bindkey "^[[3;3~" kill-word            # Option+Delete
bindkey "^[[1;2D" beginning-of-line    # Shift+Left
bindkey "^[[1;2C" end-of-line          # Shift+Right

# Поиск по истории по уже набранному префиксу (стрелки вверх/вниз)
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search
