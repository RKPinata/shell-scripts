#!/usr/bin/env bash
# Gives the session a whiteboard path and points Claude at the whiteboard skill.
set -euo pipefail

input=$(cat)
session=$(jq -r '.session_id' <<<"$input")
cwd=$(jq -r '.cwd' <<<"$input")
board=$(bash "$(dirname "$0")/../skills/whiteboard/board.sh" "$session" "$cwd")

read -r -d '' context <<TEXT || true
Your whiteboard file: $board

When an explanation is worth keeping in view beside the session, load the claude-whiteboard:whiteboard skill and follow it. Otherwise leave the whiteboard alone.
TEXT

jq -n --arg c "$context" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
