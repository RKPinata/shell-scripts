#!/usr/bin/env zsh

# Usage:
#   source delete_worktree.sh
#   or install via: ./install.sh
#
# Requirements:
# - git
# - gum
# - trash (macOS 14+)

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

if ! command -v trash >/dev/null 2>&1; then
  echo "Error: trash is not available (requires macOS 14 or later)." >&2
  return 1
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: not inside a git repository." >&2
  return 1
fi

# Clear entries whose directory is already gone, so they stay out of the list below.
git worktree prune

# Resolved through symlinks, to match the paths git reports.
current_dir="$(pwd -P)"
main_worktree="$(git worktree list --porcelain | awk '/^worktree / { sub(/^worktree /, "", $0); print; exit }')"

# Split the worktrees into deletable and locked, dropping the main worktree.
typeset -a worktrees locked_worktrees
while IFS=$'\t' read -r state wt_path; do
  [ -n "$wt_path" ] || continue
  if [ "$state" = "locked" ]; then
    locked_worktrees+=("$wt_path")
  else
    worktrees+=("$wt_path")
  fi
done < <(
  git worktree list --porcelain |
    awk -v main="$main_worktree" '
      /^worktree / { sub(/^worktree /, "", $0); path = $0; locked = 0 }
      /^locked/    { locked = 1 }
      /^$/         { emit() }
      END          { emit() }
      function emit() {
        if (path != "" && path != main) print (locked ? "locked" : "open") "\t" path
        path = ""
      }
    '
)

if (( ${#locked_worktrees[@]} > 0 )); then
  echo "Skipping locked worktrees. Run 'git worktree unlock <path>' to delete these:"
  printf ' - %s\n' "${locked_worktrees[@]}"
  echo
fi

if (( ${#worktrees[@]} == 0 )); then
  echo "No worktrees found."
  return 0
fi

# Two worktrees can share a basename, so those fall back to their full paths.
typeset -A name_count
for wt in "${worktrees[@]}"; do
  name="${wt##*/}"
  (( name_count[$name]++ ))
done

# Build display names and the mapping back to full paths.
typeset -A path_map
display_names=()

for wt in "${worktrees[@]}"; do
  name="${wt##*/}"
  (( name_count[$name] > 1 )) && name="$wt"
  display_names+=("$name")
  path_map[$name]="$wt"
done

# Show selectable list.
selected="$(
  printf '%s\n' "${display_names[@]}" |
    gum choose --no-limit --header "Select git worktrees to delete (space/x to select)"
)"

if [ -z "${selected}" ]; then
  echo "No worktrees selected."
  return 0
fi

echo
echo "The following worktrees will be moved to the Trash:"
while IFS= read -r name; do
  [ -n "$name" ] || continue
  printf ' - %s\n' "$name"
done <<< "$selected"

echo
echo "Uncommitted changes go to the Trash with the worktree; the branches are kept."
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
  if trash -s "$wt"; then
    # The directory is gone from under git; drop its admin entry so the
    # branch is not left claimed by a worktree that no longer exists.
    git worktree prune
  else
    # No Trash folder reachable from this volume.
    git worktree remove --force "$wt"
  fi
done <<< "$selected"

echo "Done."
