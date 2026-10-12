#!/bin/bash

# Trap Ctrl+C (SIGINT) and exit cleanly
trap "echo -e '\n🚪 Exiting...'; return 1 2>/dev/null || exit 1" SIGINT

# Guard: gum must be available
if ! command -v gum &>/dev/null; then
  echo "❌ gum is not installed. Exiting."
  return 1 2>/dev/null || exit 1
fi

# Guard: must be inside a Git repository
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "❌ Not inside a Git repository. Exiting."
  return 1 2>/dev/null || exit 1
fi

# Derive main checkout root — correct even when invoked from inside a worktree
MAIN_ROOT=$(git worktree list --porcelain | awk 'NR==1{sub(/^worktree /, ""); print}')
if [[ -z "$MAIN_ROOT" ]]; then
  echo "❌ Could not derive main checkout root. Exiting."
  return 1 2>/dev/null || exit 1
fi
WORKTREE_PARENT="${MAIN_ROOT}/.worktrees"
mkdir -p "$WORKTREE_PARENT"

# Mode selection
mode=$(gum filter "new branch" "existing branch") || return 1 2>/dev/null || exit 1

if [[ "$mode" == "new branch" ]]; then
  # Reset from any previous sourced run
  source_branch=""

  # Prompt for branch name
  branch_name=$(gum input --placeholder "Enter branch name") || return 1 2>/dev/null || exit 1
  # Prompt for prefix
  prefix=$(gum filter "flight" "hotfix" "feature" "bugfix" "improvement" "resolve" "other" "test") || return 1 2>/dev/null || exit 1
  # Determine base branch
  if [[ "$prefix" == "flight" || "$prefix" == "hotfix" ]]; then
    source_branch="master"
  else
    all_branches=$(git for-each-ref --sort=-committerdate refs/heads/ --format="%(refname:short)")
    flight_branches=$(echo "$all_branches" | grep "^flight/")
    other_branches=$(echo "$all_branches" | grep -v "^flight/")
    if [[ -n "$flight_branches" ]]; then
      branches=$(printf "%s\n%s" "$flight_branches" "$other_branches")
    else
      branches="$other_branches"
    fi
    source_branch=$(echo "$branches" | gum filter --header "📂 Select base branch (flight/* prioritized)") || return 1 2>/dev/null || exit 1
  fi

  if [[ -z "$source_branch" ]]; then
    echo "❌ No source branch resolved. Exiting."
    return 1 2>/dev/null || exit 1
  fi

  full_branch="${prefix}/${branch_name}"
  abs_path="${WORKTREE_PARENT}/${branch_name}"
  display_branch="$full_branch"

  # Pre-execution guard: path collision
  if [ -e "$abs_path" ]; then
    echo "❌ Directory $abs_path already exists. Exiting."
    return 1 2>/dev/null || exit 1
  fi

else
  # List local branches sorted by recent activity
  branches=$(git for-each-ref --sort=-committerdate refs/heads/ --format="%(refname:short)")

  if [[ -z "$branches" ]]; then
    echo "❌ No local branches found. Exiting."
    return 1 2>/dev/null || exit 1
  fi

  # Select existing branch
  selected_branch=$(echo "$branches" | gum filter) || return 1 2>/dev/null || exit 1
  # Derive worktree path: flatten / to _
  flattened="${selected_branch//\//_}"
  abs_path="${WORKTREE_PARENT}/${flattened}"
  display_branch="$selected_branch"
  # Pre-execution guard: path collision
  if [ -e "$abs_path" ]; then
    echo "❌ Directory $abs_path already exists. Exiting."
    return 1 2>/dev/null || exit 1
  fi

  # Pre-execution guard: branch already checked out in another worktree
  if git worktree list --porcelain | grep -q "^branch refs/heads/${selected_branch}$"; then
    echo "❌ Branch $selected_branch is already checked out in another worktree. Exiting."
    return 1 2>/dev/null || exit 1
  fi
fi

# Confirm
if [[ "$mode" == "new branch" ]]; then
  echo -e "worktree path: $abs_path\nbranch:        $display_branch\nsource:        $source_branch"
else
  echo -e "worktree path: $abs_path\nbranch:        $display_branch"
fi
gum confirm "Create worktree?" || return 1 2>/dev/null || exit 1

if [[ "$mode" == "new branch" ]]; then
  git worktree add -b "$full_branch" "$abs_path" "$source_branch"
else
  git worktree add "$abs_path" "$selected_branch"
fi

# Guard: only restore if worktree was successfully created
[[ -d "$abs_path" ]] || { echo "❌ Worktree creation failed; skipping restore."; return 1 2>/dev/null || exit 1; }

# Worktree exists — update trap to cd into it on Ctrl+C
trap "echo -e '\n🚪 Exiting...'; cd '$abs_path'; return 0 2>/dev/null || exit 0" SIGINT

# Restore local files and install dependencies.
# __WORKTREE_DIR is set by shell-integration.zsh; BASH_SOURCE covers direct execution.
_wt_dir="${__WORKTREE_DIR:-$(dirname "${BASH_SOURCE[0]:-$0}")}"
bash "${_wt_dir}/bootstrap_worktree.sh" "$abs_path"

echo ""
echo "Worktree ready at: $abs_path"
echo "Branch: $display_branch"
cd "$abs_path"
return 0 2>/dev/null || exit 0
