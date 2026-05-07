#!/usr/bin/env zsh
# Usage: source main.sh
# Must be sourced so worktree cd/delete affect the current shell.

source "${0:A:h}/shared.zsh"

all() {
  local ITEMS=(
    "worktree  › Create worktree"
    "worktree  › Switch to worktree"
    "worktree  › Delete worktree"
    "git       › Commit"
    "git       › Create branch"
    "git       › Push & set origin"
  )

  local SELECTION
  SELECTION=$(printf '%s\n' "${ITEMS[@]}" | _gm_filter "Scripts") || return 0

  case "$SELECTION" in
    *"Create worktree")    source "${__SCRIPTS_ROOT}/worktree/create_worktree.sh" ;;
    *"Switch to worktree") source "${__SCRIPTS_ROOT}/worktree/cd_worktree.sh" ;;
    *"Delete worktree")    source "${__SCRIPTS_ROOT}/worktree/delete_worktree.sh" ;;
    *"Commit")             source "${__SCRIPTS_ROOT}/gum_commit.sh" ;;
    *"Create branch")      source "${__SCRIPTS_ROOT}/gum_create_branch.sh" ;;
    *"Push & set origin")  source "${__SCRIPTS_ROOT}/git_push_set_origin.sh" ;;
  esac
}

all
