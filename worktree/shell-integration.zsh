#!/usr/bin/env zsh

# Shell integration for worktree scripts.
# Sourced from ~/.zshrc via install.sh.
# Defines: create-tree, cd-tree, del-tree

__WORKTREE_DIR="${0:A:h}"

create-tree() { source "${__WORKTREE_DIR}/create_worktree.sh"; }
cd-tree()     { source "${__WORKTREE_DIR}/cd_worktree.sh"; }
del-tree()    { source "${__WORKTREE_DIR}/delete_worktree.sh"; }
