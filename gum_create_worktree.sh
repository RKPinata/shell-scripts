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
# Set RESTORE_MODE=copy to copy local files into the worktree instead of symlinking them.
MAIN_ROOT=$(git worktree list --porcelain | awk 'NR==1{sub(/^worktree /, ""); print}')
if [[ -z "$MAIN_ROOT" ]]; then
  echo "❌ Could not derive main checkout root. Exiting."
  exit 1
fi
WORKTREE_PARENT=$(dirname "$MAIN_ROOT")

# Restore a single file or directory from MAIN_ROOT into the new worktree.
# Usage: restore_item <repo-relative-path>
restore_item() {
  local rel_path="$1"
  local source="${MAIN_ROOT}/${rel_path}"
  local target="${abs_path}/${rel_path}"

  # Source absent — skip silently
  if [[ ! -e "$source" && ! -L "$source" ]]; then
    return 0
  fi

  # Target is already the correct symlink — skip silently
  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    return 0
  fi

  # Target exists but is something else — warn and skip
  if [[ -e "$target" || -L "$target" ]]; then
    echo "  [warned]  $rel_path — target exists, skipping"
    return 0
  fi

  # Ensure parent directory exists
  mkdir -p "$(dirname "$target")"

  if [[ "${RESTORE_MODE:-symlink}" == "copy" ]]; then
    cp -r "$source" "$target"
    echo "  [copied]  $rel_path"
  else
    ln -s "$source" "$target"
    echo "  [linked]  $rel_path"
  fi
}

# Restore all files matching a shell glob under MAIN_ROOT.
# Usage: restore_glob <glob-pattern>  (e.g. ".env.*.local")
restore_glob() {
  local pattern="$1"
  for source in "${MAIN_ROOT}"/${pattern}; do
    [[ -e "$source" || -L "$source" ]] || continue
    local rel_path="${source#${MAIN_ROOT}/}"
    restore_item "$rel_path"
  done
}

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

# Guard: only restore if worktree was successfully created
[[ -d "$abs_path" ]] || { echo "❌ Worktree creation failed; skipping restore."; exit 1; }

# --- Restore local-only files ---
echo ""
echo "Restoring local files..."
restore_item ".env"
restore_item ".env.local"
restore_glob ".env.*.local"
restore_item ".env.direct"
restore_item ".env.staging"
restore_item ".env.production"
restore_item "app/.env"
restore_item "app/.env.direct"
restore_item "dev/certs"
restore_item "app/public/design-tokens.source.json"
echo "Done."

# --- Bootstrap ---
echo ""
if gum confirm "Run npm install in app/?"; then
  echo "Running npm install..."
  (cd "${abs_path}/app" && npm install) || echo "  ⚠️  npm install exited with an error"
fi

echo ""
echo "Start the app:"
echo "  cd ${abs_path}/app && npm run dev"
