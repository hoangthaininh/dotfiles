# Persistent, shared, deduped history.

HISTFILE="$XDG_STATE_HOME/zsh/history"   # keep it out of $HOME (XDG)
mkdir -p "${HISTFILE:h}"
HISTSIZE=100000
SAVEHIST=100000

setopt SHARE_HISTORY           # share in real time across every terminal
setopt EXTENDED_HISTORY        # store timestamp + duration
setopt INC_APPEND_HISTORY      # write immediately, don't wait for exit
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE       # a leading space keeps a command out of history
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY             # expand !! / !$ for confirmation, don't run blind
setopt HIST_FIND_NO_DUPS
