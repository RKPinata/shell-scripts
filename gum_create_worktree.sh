#!/bin/bash

# Trap Ctrl+C (SIGINT) and exit cleanly
trap "echo -e '\n🚪 Exiting...'; exit 1" SIGINT

# Guard: gum must be available
if ! command -v gum &>/dev/null; then
  echo "❌ gum is not installed. Exiting."
  exit 1
fi

# Guard: must be inside a Git repository
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "❌ Not inside a Git repository. Exiting."
  exit 1
fi

# Derive main checkout root — correct even when invoked from inside a worktree
MAIN_ROOT=$(git worktree list --porcelain | awk 'NR==1{sub(/^worktree /, ""); print}')
WORKTREE_PARENT=$(dirname "$MAIN_ROOT")

# Mode selection
mode=$(gum filter "new branch" "existing branch") || exit 1

if [[ "$mode" == "new branch" ]]; then
  # Prompt for branch name
  branch_name=$(gum input --placeholder "Enter branch name") || exit 1

  # Prompt for prefix
  prefix=$(gum filter "flight" "hotfix" "feature" "bugfix" "improvement" "resolve" "other" "test") || exit 1

  full_branch="${prefix}/${branch_name}"
  abs_path="${WORKTREE_PARENT}/${branch_name}"

  # Pre-execution guard: path collision
  if [ -e "$abs_path" ]; then
    echo "❌ Directory $abs_path already exists. Exiting."
    exit 1
  fi

  # Confirm
  echo -e "worktree path: $abs_path\nbranch:        $full_branch"
  gum confirm "Create worktree?" || exit 1

  git worktree add -b "$full_branch" "$abs_path"

else
  # List local branches sorted by recent activity
  branches=$(git for-each-ref --sort=-committerdate refs/heads/ --format="%(refname:short)")

  if [[ -z "$branches" ]]; then
    echo "❌ No local branches found. Exiting."
    exit 1
  fi

  # Select existing branch
  selected_branch=$(echo "$branches" | gum filter) || exit 1

  # Derive worktree path: flatten / to _
  flattened="${selected_branch//\//_}"
  abs_path="${WORKTREE_PARENT}/${flattened}"

  # Pre-execution guard: path collision
  if [ -e "$abs_path" ]; then
    echo "❌ Directory $abs_path already exists. Exiting."
    exit 1
  fi

  # Pre-execution guard: branch already checked out in another worktree
  if git worktree list --porcelain | grep -q "^branch refs/heads/${selected_branch}$"; then
    echo "❌ Branch $selected_branch is already checked out in another worktree. Exiting."
    exit 1
  fi

  # Confirm
  echo -e "worktree path: $abs_path\nbranch:        $selected_branch"
  gum confirm "Create worktree?" || exit 1

  git worktree add "$abs_path" "$selected_branch"
fi
