#!/usr/bin/env zsh

# Usage:
#   source delete_worktree.sh
#   or install via: ./install.sh
#
# Requirements:
# - git
# - gum

# Guard: must be sourced so cd can affect the terminal.
if [[ "$ZSH_EVAL_CONTEXT" != *":file"* ]]; then
  echo "Error: this script must be sourced, not executed directly." >&2
  echo "Usage: source delete_worktree.sh" >&2
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
main_worktree="$(git worktree list --porcelain | awk '/^worktree / { sub(/^worktree /, "", $0); print; exit }')"

# Collect worktree paths, excluding the main worktree (always first entry).
worktrees=("${(@f)$(
  git worktree list --porcelain |
    awk '/^worktree / { sub(/^worktree /, "", $0); print }' |
    tail -n +2
)}")

if [ "${#worktrees[@]}" -eq 0 ]; then
  echo "No worktrees found."
  return 0
fi

# Build display names (basename only) and mapping back to full paths.
typeset -A path_map
display_names=()

for wt in "${worktrees[@]}"; do
  name="${wt##*/}"
  display_names+=("$name")
  path_map[$name]="$wt"
done

# Show selectable list.
selected="$(
  printf '%s\n' "${display_names[@]}" |
    gum choose --no-limit --header "Select git worktrees to force delete (space/x to select)"
)"

if [ -z "${selected}" ]; then
  echo "No worktrees selected."
  return 0
fi

echo
echo "The following worktrees will be force deleted:"
while IFS= read -r name; do
  [ -n "$name" ] || continue
  printf ' - %s\n' "$name"
done <<< "$selected"

echo
echo "Warning: uncommitted changes in selected worktrees will be permanently lost."
gum confirm "Proceed?" || {
  echo "Aborted."
  return 0
}

# Check if we need to leave the current directory before deleting.
need_cd=false
while IFS= read -r name; do
  [ -n "$name" ] || continue
  wt="${path_map[$name]}"
  if [[ "$current_dir" == "$wt" || "$current_dir" == "$wt"/* ]]; then
    need_cd=true
    break
  fi
done <<< "$selected"

if $need_cd; then
  cd "$main_worktree"
  echo "Switched to main worktree: $main_worktree"
fi

# Delete each selected worktree.
while IFS= read -r name; do
  [ -n "$name" ] || continue
  wt="${path_map[$name]}"
  echo "Removing: $name"
  git worktree remove --force "$wt"
done <<< "$selected"

echo "Done."
