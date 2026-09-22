# tmux integration. The tmux config itself lives in ~/.config/tmux/tmux.conf
# (XDG-native since tmux 3.1); this module only wires tmux into the shell.
#
# Naming follows conf.d/aliases.zsh: t* is the tmux family the way g* is git.
# There are no wrapper functions here beyond `tp`. The one that would have been
# needed — a safe `tk` — is solved by picking from a list instead of typing a
# name, which removes the failure mode rather than checking for it:
#
#   tmux resolves -t by PREFIX when no exact match exists, so `kill-session -t cmp`
#   kills "cmp-sm-fe". Verified, not theoretical. Selecting from fzf cannot
#   mistype a name, so no exact-match guard is needed at all.

# One line per session: ● attached / ○ detached, name, window count, directory.
alias tl='tmux list-sessions -F "#{?session_attached,●,○} #{session_name}  #{session_windows}w  #{s|$HOME|~|:session_path}"'

# Bare attach to the most recent session; if nothing is running, fall through to
# the project picker — which is what you wanted anyway after a reboot.
alias ta='tmux attach 2>/dev/null || tp'

# Pick sessions to kill from a list. --multi: Tab marks several, Enter kills them.
alias tk='tmux list-sessions -F "#{session_name}" | fzf --reverse --multi --prompt="kill ❯ " | xargs -r -I{} tmux kill-session -t "={}"'

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
