#!/usr/bin/env bash
set -euo pipefail

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is not installed." >&2
  exit 1
fi

if ! command -v gum >/dev/null 2>&1; then
  echo "Error: gum is not installed." >&2
  exit 1
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: not inside a git repository." >&2
  exit 1
fi

# Collect worktree paths, excluding the main worktree (always first entry).
# Uses while-read for Bash 3.2 compatibility (no mapfile).
worktrees=()
while IFS= read -r line; do
  worktrees+=("$line")
done < <(
  git worktree list --porcelain |
    awk '/^worktree / { sub(/^worktree /, "", $0); print }' |
    tail -n +2
)

if [ "${#worktrees[@]}" -eq 0 ]; then
  echo "No worktrees found."
  exit 0
fi

# Show selectable list.
selected="$(
  printf '%s\n' "${worktrees[@]}" |
    gum choose --no-limit --header "Select git worktrees to force delete"
)"

if [ -z "${selected}" ]; then
  echo "No worktrees selected."
  exit 0
fi

echo
echo "The following worktrees will be force deleted:"
while IFS= read -r wt; do
  [ -n "$wt" ] || continue
  printf ' - %s\n' "$wt"
done <<< "$selected"

echo
echo "Warning: uncommitted changes in selected worktrees will be permanently lost."
gum confirm "Proceed?" || {
  echo "Aborted."
  exit 0
}

# Delete each selected worktree.
while IFS= read -r wt; do
  [ -n "$wt" ] || continue
  echo "Removing: $wt"
  git worktree remove --force "$wt"
done <<< "$selected"

echo "Done."