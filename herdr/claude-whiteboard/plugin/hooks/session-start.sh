#!/usr/bin/env bash
# Gives the session a whiteboard path and points Claude at the whiteboard skill.
set -euo pipefail

input=$(cat)
session=$(jq -r '.session_id' <<<"$input")
cwd=$(jq -r '.cwd' <<<"$input")
repo=$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "$cwd")")

boards="$HOME/.claude/whiteboards"
board="$boards/$repo/$session.md"
mkdir -p "$boards/$repo"

# The Herdr pane maps a terminal to its board through this file.
if [[ -n ${HC_TERMINAL_ID:-} ]]; then
  mkdir -p "$boards/.terminals"
  printf '%s\n' "$board" > "$boards/.terminals/$HC_TERMINAL_ID"
fi

read -r -d '' context <<TEXT || true
Your whiteboard file: $board

When an explanation is worth keeping in view beside the session, load the claude-whiteboard:whiteboard skill and follow it. Otherwise leave the whiteboard alone.
TEXT

jq -n --arg c "$context" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
