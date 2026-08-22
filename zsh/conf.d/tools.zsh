# External tool hooks. All guarded, so a missing tool is silent.

command -v direnv   &>/dev/null && eval "$(direnv hook zsh)"
command -v zoxide   &>/dev/null && eval "$(zoxide init zsh)"     # `z <dir>` smart jump
command -v fzf      &>/dev/null && source <(fzf --zsh)           # Ctrl-R history, Ctrl-T files
command -v starship &>/dev/null && eval "$(starship init zsh)"   # STARSHIP_CONFIG set in .zshenv

# Back fzf with fd when available (fast, respects .gitignore).
if command -v fd &>/dev/null; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi
export FZF_DEFAULT_OPTS='--height=60% --layout=reverse --border --info=inline'
