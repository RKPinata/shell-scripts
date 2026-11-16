#!/usr/bin/env bash
# Installs the Herdr mod and the Claude plugin. Run again after editing either.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)

# Herdr resolves a symlinked mod to its real path and does not hot-reload it, so the mod is copied.
mods="$HOME/.config/herdr-app/mods/claude-whiteboard"
[[ -L $mods ]] && rm "$mods"
rsync -a --delete "$here/mod/" "$mods/"
herdr-app check "$mods"

if claude plugin marketplace list 2>/dev/null | grep -q claude-whiteboard; then
  claude plugin marketplace update claude-whiteboard
else
  claude plugin marketplace add "$here"
fi
claude plugin install claude-whiteboard@claude-whiteboard
