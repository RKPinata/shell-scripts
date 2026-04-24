#!/bin/bash

# Trap Ctrl+C (SIGINT) and exit cleanly
trap "echo -e '\n🚪 Exiting...'; exit 1" SIGINT

# Check if we're inside a Git repository
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "❌ Not inside a Git repository. Exiting."
  exit 1
fi

# Prompt for branch type
branch_type=$(gum filter "flight" "hotfix" "feature" "bugfix" "improvement" "resolve" "other" "test") || exit 1

# Resolve: build branch name from selected source (merge_master_to_{source}); no name prompt
if [[ "$branch_type" == "resolve" ]]; then 
  # Get all local branches sorted by recent activity
  all_branches=$(git for-each-ref --sort=-committerdate refs/heads/ --format="%(refname:short)")

  # Separate flight/ branches from others
  flight_branches=$(echo "$all_branches" | grep "^flight/")
  other_branches=$(echo "$all_branches" | grep -v "^flight/")

  # Combine with flight/ branches on top
  branches=$(printf "%s\n%s" "$flight_branches" "$other_branches")

  # Choose parent branch
  source_branch=$(echo "$branches" | gum filter --header "📂 Select parent branch (flight/* prioritized)") || exit 1
  # Sanitize: replace / and - with _ so branch name is valid
  sanitized_source="${source_branch//\//_}"
  sanitized_source="${sanitized_source//-/_}"
  branch_name="merge_master_to_${sanitized_source}"
else
  # Prompt for branch name
  branch_name=$(gum input --placeholder "Enter branch name") || exit 1

  # Determine source branch
  if [[ "$branch_type" == "flight" || "$branch_type" == "hotfix" ]]; then
    source_branch="master"
  else
    # Get all local branches sorted by recent activity
    all_branches=$(git for-each-ref --sort=-committerdate refs/heads/ --format="%(refname:short)")

    # Separate flight/ branches from others
    flight_branches=$(echo "$all_branches" | grep "^flight/")
    other_branches=$(echo "$all_branches" | grep -v "^flight/")

    # Combine with flight/ branches on top
    branches=$(printf "%s\n%s" "$flight_branches" "$other_branches")

    # Choose parent branch
    source_branch=$(echo "$branches" | gum filter --header "📂 Select parent branch (flight/* prioritized)") || exit 1
  fi
fi

# Confirm creation
# Format branch information for display
full_branch="${branch_type}/${branch_name}"
echo -e "parent branch: $source_branch\nbranch name: $full_branch"
gum confirm "Create branch?" || exit 1

# Create the branch
git checkout -b "$full_branch" "$source_branch"
