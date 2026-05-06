#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZSHRC="${HOME}/.zshrc"

# --- Helpers ---
copy_to_clipboard() {
  local text="$1"
  local label="${2:-}"
  if echo "$text" | pbcopy 2>/dev/null; then
    echo "  📋 Copied to clipboard — just paste and run!"
  elif [[ -n "$label" ]]; then
    echo "  Copy and run the command above to $label."
  fi
}
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
  brew_cmd="brew install ${missing[*]}"
  echo "Missing required tools: ${missing[*]}"
  echo ""
  echo "Install with:"
  echo ""
  echo "  $brew_cmd"
  echo ""

  # Offer to install automatically
  read -rp "Install now via brew? [Y/n] " answer
  if [[ "$answer" =~ ^[Nn] ]]; then
    copy_to_clipboard "$brew_cmd" "install"
    exit 1
  fi

  if ! command -v brew &>/dev/null; then
    echo "Error: brew is not installed. Install Homebrew first: https://brew.sh" >&2
    copy_to_clipboard "$brew_cmd" "install"
    exit 1
  fi

  echo "Running: $brew_cmd"
  $brew_cmd || { echo "Error: brew install failed." >&2; exit 1; }
  echo ""
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
echo ""
echo "Commands available:"
echo "  create-tree   — create a new worktree"
echo "  cd-tree       — cd into a worktree"
echo "  del-tree      — delete worktrees"
echo ""
echo "Paste the following to activate the worktree commands:"
echo ""
echo "  source ~/.zshrc"
echo ""
copy_to_clipboard "source ~/.zshrc" "activate"
echo ""

