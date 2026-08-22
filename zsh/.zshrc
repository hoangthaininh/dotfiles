#!/usr/bin/env zsh
# Interactive shell entrypoint. No logic here — just load conf.d modules in order.
#
# Order is declared explicitly (not by filename) because it matters:
#   - completion (compinit) must run before plugins — fzf-tab needs it
#   - plugins sources syntax-highlighting LAST, after every ZLE widget (incl. tools)
# Alphabetical globbing would load plugins before tools and break that.

ZDOTDIR="${ZDOTDIR:-$HOME/.config/zsh}"

for module in \
  options history completion keybindings \
  tools langs tmux aliases functions plugins
do
  [[ -r "$ZDOTDIR/conf.d/$module.zsh" ]] && source "$ZDOTDIR/conf.d/$module.zsh"
done
unset module

# Fedora's /etc/zshrc drops the -U (unique) flag from $path between ~/.zshenv and here,
# which lets pyenv double-add its shims. Re-assert it after everything has loaded.
typeset -U path PATH
