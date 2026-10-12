# Shortcuts shared by zsh and fish.
#
# Sourced by config/zsh/zshrc and config/fish/config.fish. fish parses this as
# fish, so the file is limited to `alias name='body'` lines and comments — no
# functions, no command substitution, no arrays. Anything needing logic or
# arguments in the middle goes in ~/bin instead.
#
# fish's alias builtin adds --wraps, so the wrapped command's completions carry
# over in both shells.

# Git — the fish abbreviations in conf.d/inshellisense-alias-abbr.fish are
# generated from these lines, so add a git shortcut here and nowhere else.
alias g='git'
alias gst='git status'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gb='git branch'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit -v'
alias gcmsg='git commit -m'
alias gca='git commit -v -a'
alias gd='git diff'
alias gds='git diff --staged'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gl='git pull'
alias gf='git fetch'
alias glog='git log --oneline --decorate --graph'
alias glola='git log --oneline --decorate --graph --all'
alias gss='git stash'
alias gsp='git stash pop'
alias grb='git rebase'
alias grbi='git rebase -i'
alias gm='git merge'

alias pn='pnpm'

# Jump to a repo. `cd- <name>` covers these and more, from config/shell/cd-targets.
alias cdweb='cd /Users/danish/Repo/respond-io-web'
alias cdtest='cd /Users/danish/Repo/web-testing-explorations'
alias cdscripts='cd /Users/danish/scripts'

# Ghostty font presets
alias gfn='gfont next'
alias gfp='gfont prev'

# Keep the Mac awake, and hand sleep back. Both prompt for a sudo password.
# pmset itself is silent, and `&&` keeps the confirmation off the screen when
# the sudo prompt is cancelled.
alias nosleep='sudo pmset -a disablesleep 1 && echo "sleep disabled — Mac stays awake"'
alias allowsleep='sudo pmset -a disablesleep 0 && echo "sleep enabled"'
