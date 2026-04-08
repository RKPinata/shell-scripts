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
# Set RESTORE_MODE=copy to copy local files into the worktree instead of symlinking them.
MAIN_ROOT=$(git worktree list --porcelain | awk 'NR==1{sub(/^worktree /, ""); print}')
if [[ -z "$MAIN_ROOT" ]]; then
  echo "❌ Could not derive main checkout root. Exiting."
  return 1 2>/dev/null || exit 1
fi
WORKTREE_PARENT="${MAIN_ROOT}/.worktrees"
mkdir -p "$WORKTREE_PARENT"

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

# Return the lowest port >= 8080 not already claimed by an existing worktree.
find_next_port() {
  local port=8080
  while true; do
    local in_use=false
    for f in "${WORKTREE_PARENT}"/*/.dev-port; do
      [[ -f "$f" ]] || continue
      [[ "$(cat "$f")" == "$port" ]] && in_use=true && break
    done
    $in_use || { echo "$port"; return; }
    ((port++))
  done
}

# Mode selection
mode=$(gum filter "new branch" "existing branch") || return 1 2>/dev/null || exit 1

if [[ "$mode" == "new branch" ]]; then
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
    branches=$(printf "%s\n%s" "$flight_branches" "$other_branches")
    source_branch=$(echo "$branches" | gum filter --header "📂 Select base branch (flight/* prioritized)") || return 1 2>/dev/null || exit 1
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

# --- Port selection ---
suggested_port=$(find_next_port)
while true; do
  port=$(gum input --placeholder "Dev server port" --value "$suggested_port") || return 1 2>/dev/null || exit 1
  if [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1024 && port <= 65535 )); then
    break
  fi
  echo "  ⚠️  Invalid port. Enter a number between 1024 and 65535."
done

# Confirm
if [[ "$mode" == "new branch" ]]; then
  echo -e "worktree path: $abs_path\nbranch:        $display_branch\nsource:        $source_branch\nport:          $port"
else
  echo -e "worktree path: $abs_path\nbranch:        $display_branch\nport:          $port"
fi
gum confirm "Create worktree?" || return 1 2>/dev/null || exit 1

if [[ "$mode" == "new branch" ]]; then
  git worktree add -b "$full_branch" "$abs_path" "$source_branch"
else
  git worktree add "$abs_path" "$selected_branch"
fi

# Guard: only restore if worktree was successfully created
[[ -d "$abs_path" ]] || { echo "❌ Worktree creation failed; skipping restore."; return 1 2>/dev/null || exit 1; }

# Write port to worktree root (outside app/ to avoid git noise)
echo "$port" > "${abs_path}/.dev-port"

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
if gum confirm "Run npm ci in app/?"; then
  echo "Running npm ci..."
  (
    cd "${abs_path}/app" || { echo "❌ Could not cd into ${abs_path}/app"; exit 1; }
    npm ci || echo "  ⚠️  npm ci exited with an error"
  )
fi

# Write dev.sh launcher into worktree root
cat > "${abs_path}/dev.sh" <<'DEVSH'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ ! -f "$DIR/.dev-port" ]]; then
  echo "❌ .dev-port not found at $DIR/.dev-port. Re-run gmtree to recreate the worktree."
  exit 1
fi
port="$(cat "$DIR/.dev-port")"
cd "$DIR/app"
npm run dev-direct -- --port "$port"
DEVSH
chmod +x "${abs_path}/dev.sh"

echo ""
echo "Start the app:"
echo "  ${abs_path}/dev.sh"

cd "${abs_path}/app"
npm run dev-direct -- --port "$port"
