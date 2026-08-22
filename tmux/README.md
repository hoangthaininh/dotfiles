# tmux configuration

`~/.config/tmux/tmux.conf` — XDG-native, read directly by tmux ≥ 3.1, so there is
no `~/.tmux.conf`. Companion to `~/.config/zsh`.

## Prefix is `C-s`, not `C-b`

Every conventional tmux prefix is already a live binding in this zsh setup:

| key | what zsh does with it |
|---|---|
| `C-a` | `beginning-of-line` |
| `C-b` | `backward-char` |
| `C-Space` | `autosuggest-accept` |
| `C-t` | `fzf-file-widget` |
| `C-s` | `history-incremental-search-forward` — **dead**, fzf's `C-r` replaced it |

So `C-s` is the prefix. Press it twice to send a literal `C-s` to the shell.
To change it, edit the `prefix` block at the top of `tmux.conf`; `M-a` is the other
conflict-free option here (Alt is unused by this zsh config except fzf's `M-c`).

## Keys

Prefix-less:

| key | action |
|---|---|
| `M-←/→/↑/↓` | move between panes |
| `M-1..4` | jump to window 1–4 |

With prefix (`C-s` first):

| key | action |
|---|---|
| `|` / `-` | split vertical / horizontal — **inherits the pane's cwd** |
| `c` | new window in the pane's cwd |
| `h j k l` | move between panes |
| `H J K L` | resize (repeatable: hold prefix once, keep tapping) |
| `Enter` | throwaway shell popup in the pane's cwd |
| `S` | fzf session switcher |
| `G` | fzf project picker → `tp` (repos under `~/Workspace`) |
| `e` | toggle synchronize-panes (type into every pane at once) |
| `r` | reload this config |
| `X` | kill session (asks first) |
| `Backspace` | last window |
| `z` | zoom pane (stock binding, worth remembering) |
| `[` | enter copy mode — vi keys, `v` select, `y` copy to clipboard |

## Deliberate choices

- **Status bar on top.** The starship prompt is two lines tall and lives at the
  bottom; a bottom status bar collides with it.
- **Status colours = starship's `claude` palette** (`~/.config/starship/starship.toml`),
  so prompt and status bar read as one system. Change the palette in both places.
- **`mode-keys vi` despite the shell being emacs-mode.** Copy mode is modal
  navigation; that is what vi keys are for. It does not affect the command line.
- **`detach-on-destroy off`.** Killing a project session drops you into another
  session instead of ejecting you from tmux — the point of session-per-project.
- **`escape-time 10`.** The 500 ms default makes `ESC` feel broken in vim.
- **`terminal-features ...:RGB`.** Ptyxis reports `xterm-256color` but does support
  truecolor; without this tmux degrades the palette to 256 colours.
- **No plugin manager.** Same reasoning as the zsh config: nothing here needs one.
  If you ever want session persistence across reboots, that is when to add
  `tmux-resurrect` + `tmux-continuum` (and with them, tpm).

## Session per project

`prefix + G` opens the `tp` picker (`~/.config/zsh/functions/tp`), which lists live
sessions and every git repo under `~/Workspace`. See the "Session per project"
section of `~/.config/zsh/README.md` — including why session names are
collision-aware and which tmux target-syntax forms silently return empty.

## Clipboard

`set-clipboard on` (OSC 52) plus `wl-copy` for the Wayland selection. Copying in
copy mode with `y`, or by mouse-dragging, lands in the system clipboard — and still
works over SSH, since OSC 52 travels through the terminal.
