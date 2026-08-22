# Plugins — MUST load last. Required order:
#   fzf-tab -> autosuggestions -> syntax-highlighting (absolutely last)
# autosuggestions + syntax-highlighting come from Fedora rpm packages (dnf keeps them
# updated); fzf-tab is a git clone under plugins/. Wrong path? rpm -ql <package>.
# To grow past a handful of plugins later, consider antidote.

[[ -r "$ZDOTDIR/plugins/fzf-tab/fzf-tab.plugin.zsh" ]] && source "$ZDOTDIR/plugins/fzf-tab/fzf-tab.plugin.zsh"
[[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# fzf-tab config (must come after sourcing it)
zstyle ':fzf-tab:*' fzf-flags --height=60% --border
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons=auto $realpath'
zstyle ':fzf-tab:complete:z:*'  fzf-preview 'eza -1 --color=always --icons=auto $realpath'
zstyle ':fzf-tab:complete:*:*'  fzf-preview 'bat --color=always --line-range=:200 $realpath 2>/dev/null || eza -1 --color=always $realpath'

# autosuggestions
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
bindkey '^ ' autosuggest-accept   # Ctrl-Space accepts the suggestion
