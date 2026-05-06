#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZSHRC="${HOME}/.zshrc"
INTEGRATION_FILE="${SCRIPT_DIR}/shell-integration.zsh"
SOURCE_LINE="source \"${INTEGRATION_FILE}\""
MARKER_START="# --- worktree-scripts START ---"
MARKER_END="# --- worktree-scripts END ---"

# --- Validate folder structure ---
required_files=(
  "create_worktree.sh"
  "delete_worktree.sh"
  "cd_worktree.sh"
  "shell-integration.zsh"
)
for f in "${required_files[@]}"; do
  if [[ ! -f "${SCRIPT_DIR}/${f}" ]]; then
    echo "Error: missing required file: ${SCRIPT_DIR}/${f}" >&2
    exit 1
  fi
done

# --- Check prerequisites ---
missing=()
for cmd in gum git zsh; do
  if ! command -v "$cmd" &>/dev/null; then
    missing+=("$cmd")
  fi
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Error: missing required tools: ${missing[*]}" >&2
  echo "Install them before running this script." >&2
  exit 1
fi

# --- Ensure scripts are executable ---
chmod +x "${SCRIPT_DIR}/create_worktree.sh"
chmod +x "${SCRIPT_DIR}/delete_worktree.sh"
chmod +x "${SCRIPT_DIR}/cd_worktree.sh"

# --- Check .zshrc exists ---
if [[ ! -f "$ZSHRC" ]]; then
  echo "Creating ${ZSHRC} (did not exist)."
  touch "$ZSHRC"
fi

# --- Idempotency check ---
if grep -qF "$MARKER_START" "$ZSHRC"; then
  echo "Already installed. To reinstall, remove the worktree-scripts block from ${ZSHRC} and run again."
  exit 0
fi

# --- Append source line ---
{
  echo ""
  echo "$MARKER_START"
  echo "$SOURCE_LINE"
  echo "$MARKER_END"
} >> "$ZSHRC"

echo "Installed successfully."
echo "Run 'source ~/.zshrc' or open a new terminal to activate."
echo ""
echo "Commands available:"
echo "  create-tree   — create a new worktree"
echo "  cd-tree       — cd into a worktree"
echo "  del-tree      — delete worktrees"
