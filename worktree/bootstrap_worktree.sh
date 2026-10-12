#!/bin/bash

# Bootstrap a freshly created worktree: restore local-only files and install
# dependencies. Repo-specific logic lives here and nowhere else, so both
# create_worktree.sh and the creating-worktrees skill share one implementation.
#
# Usage: bootstrap_worktree.sh <abs_worktree_path>
# Set RESTORE_MODE=copy to copy local files into the worktree instead of symlinking them.

WORKTREE_PATH="$1"

if [[ -z "$WORKTREE_PATH" || ! -d "$WORKTREE_PATH" ]]; then
  echo "❌ Usage: bootstrap_worktree.sh <abs_worktree_path>"
  exit 1
fi

# Derive main checkout root from the worktree itself — no caller state needed
MAIN_ROOT=$(git -C "$WORKTREE_PATH" worktree list --porcelain | awk 'NR==1{sub(/^worktree /, ""); print}')
if [[ -z "$MAIN_ROOT" ]]; then
  echo "❌ Could not derive main checkout root. Exiting."
  exit 1
fi

# Detect repo name from git remote URL
REPO_NAME=$(git -C "$MAIN_ROOT" remote get-url origin 2>/dev/null | sed 's/.*[/:]\([^/]*\)\.git$/\1/' | sed 's/.*[/:]\([^/]*\)$/\1/')

# Non-respond-io-web repos: nothing to bootstrap
if [[ "$REPO_NAME" != "respond-io-web" ]]; then
  exit 0
fi

# Tracks whether any env file made it across
restored_env=false

# Restore a single file or directory from MAIN_ROOT into the worktree.
# Usage: restore_item <repo-relative-path>
restore_item() {
  local rel_path="$1"
  local source="${MAIN_ROOT}/${rel_path}"
  local target="${WORKTREE_PATH}/${rel_path}"

  # Source absent — skip silently
  if [[ ! -e "$source" && ! -L "$source" ]]; then
    return 0
  fi

  # Target is already the correct symlink — skip silently
  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    [[ "$rel_path" == .env* ]] && restored_env=true
    return 0
  fi

  # Seeded by the repo's post-checkout hook — skip silently
  if [[ -e "$target" || -L "$target" ]]; then
    [[ "$rel_path" == .env* ]] && restored_env=true
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

  [[ "$rel_path" == .env* ]] && restored_env=true
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

# --- Restore local-only files ---
echo ""
echo "Restoring local files..."
restore_item ".env"
restore_item ".env.local"
restore_glob ".env.*.local"
restore_item ".env.direct"
restore_item ".env.staging"
restore_item ".env.production"
restore_item "dev/certs"
restore_item "public/design-tokens.source.json"
restore_item ".eslintrc-auto-import.json"
restore_item "auto-imports.d.ts"
echo "Done."

# Never let a missing env file pass silently — the worktree will not run without one
if ! $restored_env; then
  echo ""
  echo "⚠️  No env file restored. Expected ${MAIN_ROOT}/.env or ${MAIN_ROOT}/.env.direct."
  echo "   The worktree will not start until one exists."
fi

# --- Toolchain guard ---
# pnpm-workspace.yaml sets engineStrict: true, so a version mismatch hard-fails the install.
# Resolve pnpm from inside the worktree so corepack applies the pinned packageManager
# version — checking from the caller's cwd reports the launcher version and cries wolf.
required_pnpm=$(sed -n 's/.*"packageManager"[[:space:]]*:[[:space:]]*"pnpm@\([^"]*\)".*/\1/p' "${WORKTREE_PATH}/package.json" 2>/dev/null)
installed_pnpm=$(cd "$WORKTREE_PATH" && pnpm -v 2>/dev/null)
if [[ -n "$required_pnpm" && -n "$installed_pnpm" && "${required_pnpm%%.*}" != "${installed_pnpm%%.*}" ]]; then
  echo ""
  echo "⚠️  pnpm major version mismatch: repo requires ${required_pnpm}, found ${installed_pnpm}."
  echo "   engineStrict is enabled — install will likely fail. Run: corepack use pnpm@${required_pnpm}"
fi

# --- Bootstrap: pnpm install ---
echo ""
echo "Running pnpm install..."
(
  cd "$WORKTREE_PATH" || { echo "❌ Could not cd into ${WORKTREE_PATH}"; exit 1; }
  pnpm install --frozen-lockfile || echo "  ⚠️  pnpm install exited with an error"
)

exit 0
