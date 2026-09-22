# tmux

Session-per-project, no plugins, no persistence layer. ~70 lines of settings and
one 63-line zsh function.

## The decisions, and what each one costs

### Rebuild, not restore

A tmux session lives in the server's process memory. The only thing on disk is a
zero-byte socket, so a reboot destroys every session with no recovery path. There
are two honest answers, and they are not equivalent:

|          | restore (tmux-resurrect, continuum) | rebuild (here) |
| -------- | ----------------------------------- | -------------- |
| source   | a snapshot of whatever was open     | code in git |
| result   | varies with what you last left open | one known result, always |
| captures | hand-made arrangements              | only what is described |
| on a new machine | needs the save file to travel | works from a clone |
| failure mode | stale dirs, dead branches, scrollback that reads like live output but is a screenshot | a layout you hand-tuned is gone |

**Cost of this choice:** if you spend ten minutes arranging panes for a debugging
session, a reboot takes it. That is real and it is the price.

**Why it is still right here:** the alternative makes `tp` non-deterministic —
what you get tomorrow depends on what you happened to leave open, which is exactly
the state you cannot reason about at 9am. A previous version of this config auto-
saved layouts on seven hooks; it worked, and it was deleted, because a race guard
and 90 lines of layout serialisation is a lot of machinery to make a terminal
multiplexer less predictable.

### No plugin manager

tpm needs a bootstrap step, a network fetch and pinning discipline. tmux's value
is being there when everything else is broken; a config that clones from GitHub
on first run is not that. Everything here is a tmux built-in.

**Cost:** no ready-made status themes, no resurrect even if wanted later.

### Two windows, no editor pane

Chosen from this machine's shell history (716 commands), not from convention:

```
265  git       37%
 98  npm/pnpm  14%
 36  code            → VS Code, a GUI app
 36  claude
  0  vim/nvim        → never run; not installed
```

So `dev` (for the process that blocks a prompt) and `git` (a free prompt, opened
first). No editor pane — the editor is not in the terminal. No four-pane grid: an
idle pane costs screen height on every window it appears in.

**Cost:** more prefix+c and prefix+| than a pre-tiled layout.

### prefix = C-s

`C-b` is backward-char, `C-a` is beginning-of-line, `C-Space` is autosuggest-accept
and `C-t` is fzf-file-widget — all live in this zsh. `C-s` is normally terminal
flow control (XOFF) and would freeze the pane, but `conf.d/options.zsh` sets
`NO_FLOW_CONTROL`, so it is free. The two are coupled: **removing
`NO_FLOW_CONTROL` breaks this prefix.**

**Cost:** zsh's forward-i-search, already redundant next to fzf's `C-r`.

### Killing sessions by picking, not typing

tmux resolves `-t` by prefix when no exact match exists, so
`tmux kill-session -t cmp` kills `cmp-sm-fe`. Verified, not theoretical. Rather
than wrap that in a guard function, `tk` pipes the session list through fzf: you
cannot mistype a name you did not type. The failure mode is removed instead of
checked for.

## Commands

| | |
| --- | --- |
| `tp` | picker: live sessions (●) then git repos (○) |
| `tp <dir>` | open that project, create if needed |
| `tl` | list sessions with window count and directory |
| `ta` | attach to the most recent session, else the picker |
| `tk` | pick sessions to kill (Tab for several) |
| `td` | detach, leaving everything running |

| key | |
| --- | --- |
| `prefix G` | project picker |
| `prefix S` | switch between running sessions |
| `prefix Enter` | throwaway shell in this pane's directory |
| `prefix \| -` | split, inheriting the current directory |
| `prefix c` | new window, same |
| `Alt+arrows` | move between panes, no prefix |
| `Alt+1..4` | jump to window, no prefix |
| `prefix r` | reload this config |
| `prefix X` | kill this session (confirms) |

## Files

```
tmux/tmux.conf              settings and bindings
zsh/functions/tp            the project switcher
zsh/conf.d/tmux.zsh         aliases and completion
```

`~/.config/tmux` symlinks to `tmux/` here.
