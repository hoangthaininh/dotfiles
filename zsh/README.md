# zsh configuration

XDG-based zsh setup. Everything lives under `~/.config/zsh/` except one bootstrap
file that zsh forces to live in `$HOME` (see below).

> `~/.config/zsh` is a **symlink** into the dotfiles repo
> (`~/Workspace/personal/dotfiles/zsh`) — see the repo's top-level README. Every
> path below is written as `~/.config/...` because that is what the tools resolve;
> the symlink is transparent to all of them.

## Layout

```
~/.zshenv                 # BOOTSTRAP — must be in $HOME (see "The ~/.zshenv gotcha")
~/.config/zsh/
├── .zshrc                # entrypoint: loads conf.d modules in an explicit order
├── conf.d/               # one module per concern, loaded in the order set by .zshrc
│   ├── options.zsh       # setopt
│   ├── history.zsh
│   ├── completion.zsh    # compinit + zstyle
│   ├── keybindings.zsh
│   ├── tools.zsh         # starship / zoxide / fzf / direnv hooks
│   ├── langs.zsh         # nvm (+ .nvmrc auto-switch), pyenv
│   ├── tmux.zsh          # TP_PROJECT_DIRS, t* aliases, tp completion
│   ├── aliases.zsh
│   ├── functions.zsh     # autoload from functions/
│   └── plugins.zsh       # fzf-tab -> autosuggestions -> syntax-highlighting (last)
├── functions/            # one autoloaded function per file (mkcd, extract, tp)
├── plugins/              # git-cloned plugins — GITIGNORED, cloned on install
└── README.md
```

tmux lives separately too: `~/.config/tmux/tmux.conf` (see its own README — the
prefix is `C-s` because `C-a`/`C-b`/`C-Space`/`C-t` are all bound here).

Starship lives separately: `~/.config/starship/starship.toml` (pointed to by
`STARSHIP_CONFIG` in `.zshenv`).

## The `~/.zshenv` gotcha

`~/.zshenv` **must** sit in `$HOME`, not in `~/.config/zsh/`. zsh reads
`$HOME/.zshenv` first, before `ZDOTDIR` is known — and that file is what sets
`ZDOTDIR=~/.config/zsh` so every other file loads from there. Put it anywhere else
and nothing loads.

To keep it tracked in this repo, store the real file here and symlink it into `$HOME`:

```sh
# from the repo (adjust path to where this repo lives)
ln -sf ~/.config/zsh/zshenv ~/.zshenv
```

(zsh follows the symlink fine.) The tracked copy in this repo is `zshenv` — keep it
in sync with `~/.zshenv`.

## Prerequisites (Fedora)

```sh
# shell plugins (sourced from /usr/share) + core CLI tools
sudo dnf install zsh zsh-autosuggestions zsh-syntax-highlighting \
     fzf zoxide eza bat fd-find ripgrep direnv git tmux wl-clipboard

# starship prompt (not in the default repos)
curl -sS https://starship.rs/install.sh | sh

# a Nerd Font, for starship's glyphs (e.g. FiraCode / JetBrainsMono Nerd Font)
```

Optional, only if used (all guarded — the config runs fine without them):
`nvm`, `pyenv`, `pnpm`.

## Install on a new machine

See the **top-level README** of the dotfiles repo — it covers cloning, the three
`~/.config` symlinks, packages, starship, and `chsh` in one place.

The two steps specific to this directory, repeated here because they are easy to
miss:

```sh
# ~/.zshenv MUST be in $HOME (see the gotcha above); symlink it out of the repo
ln -sf ~/.config/zsh/zshenv ~/.zshenv

# plugins/ is gitignored — clone fzf-tab
git clone --depth=1 https://github.com/Aloxaf/fzf-tab ~/.config/zsh/plugins/fzf-tab
```

## Session per project (`tp`)

One tmux session per project, named after the project directory.

```sh
tp                 # fzf picker: live sessions (●) first, then git repos (○)
tp ~/work/api      # session for that directory, created if it isn't running
tp api             # attach to a live session by exact name
```

Also bound to **prefix + G** inside tmux (opens the picker in a popup).

The picker's project list comes from two sources, unioned and deduped:

1. git repos up to `$TP_MAX_DEPTH` (7) levels below each entry in `$TP_PROJECT_DIRS`
   — currently just `~/Workspace`, both set in `conf.d/tmux.zsh`
2. zoxide's frecent directories that contain a `.git`, which catches repos
   outside those roots

The depth cap is load-bearing, not decoration: repos here live at
`Workspace/<scope>/<org>/<group>/<repo>`, i.e. **3–5 levels down**, so a shallow
2-level scan finds exactly nothing. Scanning is `fd`-based (~10 ms for 14 repos)
with `node_modules`, `.venv` and `vendor` excluded; the fallback when `fd` is absent
is a `**/.git` glob.

A project that already has a live session is listed once, as the session.
Matching is by **directory**, not by name, so the two same-named repos below can
never mask each other.

### Default layout

| window | contents |
|---|---|
| 1 `code` | one full-height pane, for `$EDITOR` |
| 2 `run` | 4 tiled panes: frontend / backend / logs / spare shell |
| 3 `git` | one pane |

### Per-project layout

Drop an executable `.tmux-project` in a repo root and it replaces the default
layout. It runs after the session exists with window `code`, and receives
`$1` = session name, `$2` = project dir:

```sh
#!/usr/bin/env bash
tmux new-window   -t "=$1:" -c "$2" -n server
tmux split-window -h -t "=$1:server" -c "$2"
tmux send-keys    -t "=$1:server.1" 'pnpm dev' C-m
```

### Session names, and why they are collision-aware

The directory basename, with `.` `:` and spaces folded to `_` and anything else
non-alphanumeric dropped — so `~/work/my.app` becomes session `my_app`. tmux target
syntax reads `:` and `.` as separators (`session:window.pane`), so a literal one in
a session name makes the session unaddressable.

A bare basename is not enough. In a nested tree, **two different repos can share a
basename** — a base template checked out both at the top of an org and again inside
one product line:

```
work/acme/apps/web-app
work/acme/apps/storefront/web-app
```

Keyed on the basename alone, `tp` would attach to the wrong project — silently, and
you would run the dev server against the wrong repo. Instead, every session records
its project directory in the `@tp_dir` session option, and on a clash `tp` walks up
the path until the name is either free or already its own:

```
web-app              ->  work/acme/apps/web-app
storefront_web-app   ->  work/acme/apps/storefront/web-app
```

Three parent levels are tried before it gives up with an error.

### tmux target-syntax traps

Both of these cost real debugging time; don't undo them.

- **`"=name"` forces an exact match** — without it, `api` resolves to `api-gateway`.
  It works for `has-session`, `new-window`, `split-window`, `attach-session` and
  `switch-client`. It does **not** work for `set-option`, `show-option` or
  `display-message`: those return **empty, without erroring**. That is why `tp` reads
  `@tp_dir` via `list-sessions` plus an exact compare in zsh, never via `-t "=name"`.
- **Always brace `${name}` before a `:`** — zsh reads `$name:r` and `$name:c` as
  history modifiers, so `"=$name:run"` silently expands to `my_appun` and every
  window-targeted command fails with `can't find window`.
- **`#{session_path}` does not exist** in tmux 3.7 (it expands to empty), which is
  the other reason for the `@tp_dir` option.

## Notes

- **Load order is explicit** in `.zshrc` (not by filename). It matters: completion
  must precede plugins, and syntax-highlighting must be sourced last. Don't switch to
  alphabetical globbing.
- **`typeset -U path` is re-asserted at the end of `.zshrc`** because Fedora's
  `/etc/zshrc` drops the unique flag, which otherwise lets pyenv double-add its shims.
- **nvm** activates the `default` alias at startup (node/npm always available), and
  auto-switches per project via `.nvmrc` on `cd`. Keep `default` pointed at an
  *installed* version (`nvm alias default <version>`) — the stock `lts/*` can resolve
  to a version you haven't installed and break `nvm use default`.
- **tmux's prefix is `C-s`**, chosen because `C-a`/`C-b`/`C-Space`/`C-t` are all
  live bindings in `keybindings.zsh` / `plugins.zsh`. If you rebind any of those,
  re-check `~/.config/tmux/tmux.conf`.
- **`TP_PROJECT_DIRS`** (in `conf.d/tmux.zsh`) is the one thing to edit per machine.
  Here it is `~/Workspace` with `TP_MAX_DEPTH=7`, matching repos that sit 3-5 levels
  deep. Raise the depth before adding a root that nests deeper.
- **`claude`** (and similar CLIs) should be installed node-independently
  (`claude install` -> `~/.local/bin`), not as an nvm-scoped npm global, or they
  vanish when the active node version changes.
