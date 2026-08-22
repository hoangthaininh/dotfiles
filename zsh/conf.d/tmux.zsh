# tmux integration. The tmux config itself lives in ~/.config/tmux/tmux.conf
# (XDG-native since tmux 3.1); this module only wires tmux into the shell.

# Where `tp` looks for projects: any git repo up to $TP_MAX_DEPTH levels below these
# roots. Repos here sit 3-5 levels deep (Workspace/<scope>/<org>/<group>/<repo>), so
# the depth cap matters — a shallow scan finds nothing.
# zoxide's frecent directories are scanned too, so repos outside these roots still
# show up in the picker.
typeset -ga TP_PROJECT_DIRS
TP_PROJECT_DIRS=(
  "$HOME/Workspace"
)
typeset -g TP_MAX_DEPTH=7

alias tl='tmux list-sessions'
alias ta='tmux attach-session -t'
alias tk='tmux kill-session -t'
alias td='tmux detach-client'

# Completion for tp: live sessions by name, then directories.
_tp() {
  local -a sessions
  sessions=( ${(f)"$(tmux list-sessions -F '#{session_name}' 2>/dev/null)"} )
  _alternative \
    "sessions:tmux session:(${sessions[*]})" \
    'dirs:project directory:_files -/'
}
compdef _tp tp

# Same exact-match completion for the raw tmux aliases.
_tmux_sessions() {
  local -a sessions
  sessions=( ${(f)"$(tmux list-sessions -F '#{session_name}' 2>/dev/null)"} )
  _describe -t sessions 'tmux session' sessions
}
compdef _tmux_sessions ta
compdef _tmux_sessions tk
