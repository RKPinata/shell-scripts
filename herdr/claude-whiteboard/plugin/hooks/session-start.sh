#!/usr/bin/env bash
# Gives the session a whiteboard path and tells Claude how to use it.
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
Your whiteboard for this session: $board

The user reads this file in a Herdr pane beside the session. It is for the user only. It is temporary and is not a source of truth.

- Write to it when you explain something worth keeping in view: a flow, a design, the current plan, what you found. Skip it for short answers.
- Keep it current. Rewrite the whole file with Write each time. Delete what no longer matters. Do not append a log.
- Use markdown. Draw flows, sequences, states and structures as \`\`\`mermaid blocks (flowchart, sequenceDiagram, stateDiagram-v2, classDiagram, erDiagram).
- Create the file on first write. You do not need to announce updates in chat.
TEXT

jq -n --arg c "$context" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
