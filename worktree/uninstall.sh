#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZSHRC="${HOME}/.zshrc"
MARKER_START="# --- worktree-scripts START ---"
MARKER_END="# --- worktree-scripts END ---"

copy_to_clipboard() {
  local text="$1"
  local label="${2:-}"
  if echo "$text" | pbcopy 2>/dev/null; then
    echo "  Copied to clipboard — just paste and run!"
  elif [[ -n "$label" ]]; then
    echo "  Copy and run the command above to $label."
  fi
}

# --- Idempotency check ---
if ! grep -qF "$MARKER_START" "$ZSHRC" 2>/dev/null; then
  echo "Not installed (no worktree-scripts block found in ${ZSHRC})."
  exit 0
fi

# --- Remove the block ---
if ! sed -i '' "/$(printf '%s\n' "$MARKER_START" | sed 's/[\/&]/\\&/g')/,/$(printf '%s\n' "$MARKER_END" | sed 's/[\/&]/\\&/g')/d" "$ZSHRC"; then
  echo "Error: failed to remove worktree-scripts block from ${ZSHRC}." >&2
  exit 1
fi

echo "Uninstalled successfully."
echo ""
echo "Activate changes by running:"
echo ""
echo "  source ~/.zshrc"
echo ""
copy_to_clipboard "source ~/.zshrc" "activate"
echo ""

# --- Optional gum removal ---
read -rp "Remove gum via brew? [y/N] " answer
if [[ "$answer" =~ ^[Yy] ]]; then
  if ! command -v brew &>/dev/null; then
    echo "Warning: brew is not installed — skipping gum removal."
  else
    echo "Running: brew uninstall gum"
    brew uninstall gum || echo "Warning: brew uninstall gum failed. You can remove it manually."
  fi
fi
