# dotfiles

Shell environment: zsh + starship + tmux. Fedora, Wayland, GNOME.

The three directories live here and are **symlinked into `~/.config`**, so every
tool still finds its config at the XDG path it expects:

```
~/.config/zsh      -> ../Workspace/personal/dotfiles/zsh
~/.config/tmux     -> ../Workspace/personal/dotfiles/tmux
~/.config/starship -> ../Workspace/personal/dotfiles/starship
~/.zshenv          -> ~/.config/zsh/zshenv        (resolves through the symlink)
```

## Why one repo, and why not rooted at `~/.config`

**One repo**, because the three are coupled. The starship prompt and the tmux
status bar share one palette — `#D9773C` coral is defined in both
`starship/starship.toml` and `tmux/tmux.conf` — so a palette change is one commit,
not two commits in two repos. `zsh/conf.d/tmux.zsh` and `zsh/functions/tp` also
only make sense next to `tmux/tmux.conf`.

**Not rooted at `~/.config`**, because that directory also holds 5+ GB of browser
profiles and `gh/hosts.yml` (a live GitHub OAuth token). A repo there would put one
`git clean -xfd` between you and your entire desktop state, and one `.gitignore`
mistake between you and a leaked token. Symlinks cost nothing and remove both risks.

## Layout

```
zsh/            see zsh/README.md — XDG layout, conf.d load order, the ~/.zshenv gotcha
tmux/           see tmux/README.md — why the prefix is C-s, key table, session-per-project
starship/       starship.toml — two-line prompt, "claude" coral palette
```

## Install on a new machine

```sh
# 1. clone
git clone <remote> ~/Workspace/personal/dotfiles
cd ~/Workspace/personal/dotfiles

# 2. symlink into ~/.config (move any existing dirs out of the way first)
for d in zsh tmux starship; do
  ln -s "../Workspace/personal/dotfiles/$d" "$HOME/.config/$d"
done

# 3. the one file zsh forces to live in $HOME (see zsh/README.md)
ln -sf ~/.config/zsh/zshenv ~/.zshenv

# 4. packages
sudo dnf install zsh zsh-autosuggestions zsh-syntax-highlighting \
     fzf zoxide eza bat fd-find ripgrep direnv git tmux wl-clipboard

# 5. starship — not in the Fedora repos, and dnf will never update it.
#    Installed to ~/.local/bin (first in $PATH), so no root needed.
curl -sS https://starship.rs/install.sh | sh -s -- --bin-dir "$HOME/.local/bin"

# 6. plugins/ is gitignored — clone fzf-tab
git clone --depth=1 https://github.com/Aloxaf/fzf-tab ~/.config/zsh/plugins/fzf-tab

# 7. make zsh the login shell
chsh -s "$(command -v zsh)"
```

A Nerd Font is required for the prompt and status-bar glyphs
(`⚘`, `⚊泰蛟⚋`, ``). This machine uses IosevkaTermSlab Nerd Font.

## Per-machine bits that are deliberately NOT tracked

- `zsh/plugins/` — vendored git clones, re-cloned on install (step 6)
- `TP_PROJECT_DIRS` in `zsh/conf.d/tmux.zsh` **is** tracked but is the one value to
  edit per machine: it lists the roots `tp` scans for git repos (`~/Workspace` here)
