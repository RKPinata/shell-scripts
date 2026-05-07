#!/usr/bin/env zsh

# Shell integration for worktree scripts.
# Sourced from ~/.zshrc via install.sh.
# Defines: create-tree, cd-tree, del-tree, tree

source "${0:A:h}/../shared.zsh"

__WORKTREE_DIR="${__SCRIPTS_ROOT}/worktree"

create-tree() { source "${__WORKTREE_DIR}/create_worktree.sh"; }
cd-tree()     { source "${__WORKTREE_DIR}/cd_worktree.sh"; }
del-tree()    { source "${__WORKTREE_DIR}/delete_worktree.sh"; }

tree() {
  local ITEMS=(
    "Create worktree"
    "Switch to worktree"
    "Delete worktree"
  )

  local SELECTION
  SELECTION=$(printf '%s\n' "${ITEMS[@]}" | _gm_filter "Worktree") || return 0

  case "$SELECTION" in
    "Create worktree")    source "${__WORKTREE_DIR}/create_worktree.sh" ;;
    "Switch to worktree") source "${__WORKTREE_DIR}/cd_worktree.sh" ;;
    "Delete worktree")    source "${__WORKTREE_DIR}/delete_worktree.sh" ;;
  esac
}
