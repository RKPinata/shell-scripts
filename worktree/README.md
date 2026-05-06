# Worktree Scripts

Interactive git worktree management powered by [gum](https://github.com/charmbracelet/gum).

## Prerequisites

- **zsh** — your default shell
- **git** — version control
- **gum** — interactive TUI prompts
  - macOS: `brew install gum`
  - Linux: see [gum install docs](https://github.com/charmbracelet/gum#installation)

## Installation

Clone this repo and run the installer:

    git clone https://github.com/RKPinata/shell-scripts.git ~/scripts
    ./scripts/worktree/install.sh

Then activate in your current session:

    source ~/.zshrc

## Commands

### create-tree

Create a new worktree from a new or existing branch. Prompts for branch name,
prefix, base branch, and dev server port. Restores environment files and
optionally runs `npm ci`.

### cd-tree

Switch into an existing worktree. Presents a list of all worktrees
(excluding the current directory) and `cd`s into the selected one.

### del-tree

Select one or more worktrees to force-delete. Warns about uncommitted
changes before proceeding.

## Uninstall

Remove the following block from `~/.zshrc`:

    # --- worktree-scripts START ---
    source "/path/to/worktree/shell-integration.zsh"
    # --- worktree-scripts END ---
