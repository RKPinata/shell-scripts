#!/usr/bin/env zsh
# Shared utilities. Sourced by main.sh and shell-integration.zsh.

__SCRIPTS_ROOT="${0:A:h}"

# Common gum filter — pipe items via stdin, pass header as $1
_gm_filter() {
  if ! command -v gum &>/dev/null; then
    echo "❌ gum is not installed."
    return 1
  fi
  gum filter \
    --header "${1:-Scripts}" \
    --placeholder "filter..." \
    --prompt "  " \
    --height=12
}
