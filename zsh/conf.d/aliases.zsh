# Aliases.
# Naming: 1-2 chars for daily commands; a domain prefix for families (g* = git);
# never silently change a command's meaning (the rm/cp/mv -i block below is the one
# deliberate exception); anything needing arguments or logic goes in functions/.

# ls / eza
alias ls='eza --group-directories-first --icons=auto'
alias ll='eza -lah --group-directories-first --icons=auto --git'
alias la='eza -a  --group-directories-first --icons=auto'
alias lt='eza --tree --level=2 --icons=auto'

# view / search
alias cat='bat --paging=never'
alias less='bat'
alias grep='grep --color=auto'

# navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias d='dirs -v'

# git
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gc='git commit'
alias gca='git commit --amend'
alias gco='git checkout'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate -20'
alias gp='git push'
alias gpl='git pull'
alias gb='git branch'

# dnf
alias dnfi='sudo dnf install'
alias dnfu='sudo dnf upgrade --refresh'
alias dnfs='dnf search'
alias dnfr='sudo dnf remove'

# misc
alias reload='exec zsh'
alias path='echo -e ${PATH//:/\\n}'
alias ip='ip -color=auto'

# Safety: prompt before clobbering (delete these three if they get in the way).
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
