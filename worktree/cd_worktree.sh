#!/usr/bin/env zsh

# Usage:
#   source cd_worktree.sh
#   or install via: ./install.sh
#
# Requirements:
# - git
# - gum

# Guard: prevent direct execution (cd would affect a subshell, not the terminal)
if [[ "$ZSH_EVAL_CONTEXT" != *":file"* ]]; then
  echo "Error: this script must be sourced, not executed directly." >&2
  echo "Usage: source cd_worktree.sh" >&2
  echo "       or install via: ./worktree/install.sh" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is not installed." >&2
  return 1
fi

if ! command -v gum >/dev/null 2>&1; then
  echo "Error: gum is not installed." >&2
  return 1
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: not inside a git repository." >&2
  return 1
fi

current_dir="$(pwd)"

worktrees=("${(@f)$(
  git worktree list --porcelain |
    awk '/^worktree / { sub(/^worktree /, "", $0); print }' |
    grep -Fxv "$current_dir"
)}")

if [ "${#worktrees[@]}" -eq 0 ]; then
  echo "No other worktrees found."
  return 0
fi

selected="$(
  printf '%s\n' "${worktrees[@]}" |
    gum choose --header "Select a git worktree to cd into"
)"

if [ -z "${selected}" ]; then
  echo "No worktree selected."
  return 0
fi

if cd "$selected"; then
  echo "Changed directory to: $selected"
else
  echo "Error: failed to cd into '$selected'." >&2
  return 1
fi
