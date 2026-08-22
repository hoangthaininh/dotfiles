# Version managers. Base PATH is set in ~/.zshenv.
# Easiest module to swap for mise later: replace the whole file with
#   command -v mise &>/dev/null && eval "$(mise activate zsh)"

# nvm — auto-activates the `default` alias at startup so node/npm are always present.
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Auto-switch node per project: `nvm use` on entering a dir with .nvmrc,
# back to the default version on leaving.
if command -v nvm &>/dev/null; then
  autoload -Uz add-zsh-hook
  _load_nvmrc() {
    local nvmrc; nvmrc="$(nvm_find_nvmrc)"
    if [[ -n "$nvmrc" ]]; then
      local want; want=$(nvm version "$(cat "$nvmrc")")
      if [[ "$want" == "N/A" ]]; then nvm install
      elif [[ "$want" != "$(nvm version)" ]]; then nvm use --silent
      fi
    elif [[ -n "$(PWD=$OLDPWD nvm_find_nvmrc)" && "$(nvm version)" != "$(nvm version default)" ]]; then
      nvm use default --silent
    fi
  }
  add-zsh-hook chpwd _load_nvmrc
  _load_nvmrc
fi

# pyenv — init virtualenv only if the plugin is actually installed (avoids an error).
if command -v pyenv &>/dev/null; then
  eval "$(pyenv init - zsh)"
  pyenv commands 2>/dev/null | grep -qx virtualenv-init && eval "$(pyenv virtualenv-init - zsh)"
fi
