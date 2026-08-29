# Fish trial configuration for Ghostty.
# The macOS login shell remains zsh, so ~/.zshrc is still available as a fallback.

if set -q GHOSTTY_RESOURCES_DIR
    set -gx EDITOR fresh
    set -gx VISUAL fresh
else
    set -gx EDITOR "zed --wait"
    set -gx VISUAL "zed --wait"
end
set -gx USE_BUILTIN_RIPGREP 0

set -gx BUN_INSTALL $HOME/.bun
set -gx ANDROID_HOME $HOME/Library/Android/sdk

fish_add_path --global --prepend \
    $HOME/bin \
    $HOME/.local/bin \
    $BUN_INSTALL/bin \
    /opt/homebrew/bin \
    /opt/homebrew/sbin

fish_add_path --global --append \
    $ANDROID_HOME/emulator \
    $ANDROID_HOME/platform-tools

if status is-interactive
    fnm env --use-on-cd --shell fish | source
    zoxide init fish --cmd j | source

    # Initialize the complete preset map before fzf adds user bindings.
    fish_default_key_bindings
    fzf --fish | source

    # carapace supplies dynamic completions (git branches, docker names) for
    # commands fish has no completer for. Bridges fall back to zsh/bash
    # completers when carapace has no spec.
    set -gx CARAPACE_BRIDGES zsh,bash
    carapace _carapace fish | source

    # Ghostty sends private sequences for macOS-style selection shortcuts.
    # Start a selection once, then preserve its anchor while repeated keys
    # extend or shrink it.
    function __editor_extend_selection --argument-names movement
        if commandline --selection-start >/dev/null 2>&1
            commandline -f $movement
        else
            commandline -f begin-selection $movement
        end
    end

    bind shift-left '__editor_extend_selection backward-char'
    bind shift-right '__editor_extend_selection forward-char'
    bind alt-shift-left '__editor_extend_selection backward-word'
    bind alt-shift-right '__editor_extend_selection forward-word'
    bind shift-up '__editor_extend_selection up-line'
    bind shift-down '__editor_extend_selection down-line'

    # Ghostty translates Cmd-Shift arrows to these Ctrl-X-prefixed sequences.
    bind (printf '\x18\x01') '__editor_extend_selection beginning-of-line'
    bind (printf '\x18\x05') '__editor_extend_selection end-of-line'
    bind (printf '\x18\x10') '__editor_extend_selection beginning-of-buffer'
    bind (printf '\x18\x0e') '__editor_extend_selection end-of-buffer'

    # Moving without shift drops the anchor, so the next keystroke does not
    # delete a stale selection.
    function __editor_clear_selection --argument-names movement
        commandline -f end-selection
        commandline -f $movement
    end

    bind left '__editor_clear_selection backward-char'
    bind right '__editor_clear_selection forward-char'
    bind home '__editor_clear_selection beginning-of-line'
    bind end '__editor_clear_selection end-of-line'

    # A keystroke with a live selection replaces it, as in a text field.
    function __editor_replace_selection --argument-names fallback
        if commandline --selection-start >/dev/null 2>&1
            commandline -f kill-selection
            commandline -f end-selection
        end
        commandline -f $fallback
    end

    bind backspace '__editor_replace_selection backward-delete-char'
    bind delete '__editor_replace_selection delete-char'
end

# Git aliases preserved from ~/.zshrc.
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
alias cdweb='cd /Users/danish/Repo/respond-io-web'
alias cdtest='cd /Users/danish/Repo/web-testing-explorations'
alias gfn='gfont next'
alias gfp='gfont prev'

# Git helper scripts run in Bash and do not need to modify fish state.
function gmcm
    command bash /Users/danish/scripts/gum_commit.sh $argv
end

function gmbr
    command bash /Users/danish/scripts/gum_create_branch.sh $argv
end

function gpso
    command bash /Users/danish/scripts/git_push_set_origin.sh $argv
end

# Worktree scripts remain unchanged. Run them in zsh, then mirror any
# resulting directory change back into the current fish process.
function __run_zsh_worktree_helper --argument-names script
    set -l cwd_file (command mktemp -t fish-worktree-cwd.XXXXXX)
    or return 1

    command zsh -c 'source "$1"; rc=$?; pwd -P > "$2"; exit $rc' \
        zsh $script $cwd_file
    set -l exit_status $status

    if test -s $cwd_file
        set -l next_dir (string trim -- (command cat $cwd_file))
        if test -d "$next_dir"
            cd "$next_dir"
        end
    end

    command rm -f $cwd_file
    return $exit_status
end

function create-tree
    __run_zsh_worktree_helper /Users/danish/scripts/worktree/create_worktree.sh
end

function cd-tree
    __run_zsh_worktree_helper /Users/danish/scripts/worktree/cd_worktree.sh
end

function del-tree
    __run_zsh_worktree_helper /Users/danish/scripts/worktree/delete_worktree.sh
end

function tree
    set -l selection (printf '%s\n' \
        'Create worktree' \
        'Switch to worktree' \
        'Delete worktree' | gum filter --header 'Worktree')
    or return 0

    switch $selection
        case 'Create worktree'
            create-tree
        case 'Switch to worktree'
            cd-tree
        case 'Delete worktree'
            del-tree
    end
end



test -f '/Users/danish/.local/share/inshellisense/init/fish/init.fish' && source '/Users/danish/.local/share/inshellisense/init/fish/init.fish'
