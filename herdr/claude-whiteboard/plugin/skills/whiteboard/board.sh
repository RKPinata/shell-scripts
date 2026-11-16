#!/usr/bin/env bash
# Prints the session's whiteboard path, creates its folder, and maps the Herdr terminal to it.
# Usage: board.sh [session-id] [cwd]   (defaults: $CLAUDE_CODE_SESSION_ID, $PWD)
set -euo pipefail

session=${1:-${CLAUDE_CODE_SESSION_ID:-}}
cwd=${2:-$PWD}
[[ -n $session ]] || { echo "board.sh: no session id; pass one or set CLAUDE_CODE_SESSION_ID" >&2; exit 1; }
repo=$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "$cwd")")

boards="$HOME/.claude/whiteboards"
board="$boards/$repo/$session.md"
mkdir -p "$boards/$repo"

# The Herdr pane maps a terminal to its board through this file.
if [[ -n ${HC_TERMINAL_ID:-} ]]; then
  mkdir -p "$boards/.terminals"
  printf '%s\n' "$board" > "$boards/.terminals/$HC_TERMINAL_ID"
fi

printf '%s\n' "$board"
