# Command-line key bindings.

bindkey -e   # emacs mode (explicit rather than relying on the default)

# Ctrl-X Ctrl-E: edit the current command in $EDITOR (long/multi-line commands)
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# Home / End / Delete
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char

# Ctrl-Left / Ctrl-Right: move by word
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# Up/Down: search history by the prefix already typed
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
