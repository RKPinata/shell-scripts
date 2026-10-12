#!/usr/bin/env bash
# `cloc`: start Claude Code with plugins loaded from local checkouts through
# --plugin-dir, so skill edits take effect without publishing a version.
#
#   cloc                    pick plugins with gum
#   cloc all                load every plugin in the registry
#   cloc <name...>          load the named plugins
#   cloc ... -- <args>      pass <args> on to claude
#   cloc add [dir]          register a plugin directory (default: current one)
#   cloc delete [name...]   remove registry entries
#   cloc list               print the registry
#   cloc install-test [name] install from a throwaway copy of the marketplace
set -euo pipefail

registry="$(dirname "$0")/config/claude/local-plugins"

entries() { grep -v '^#' "$registry" | grep -v '^$' || true; }

path_of() { entries | awk -v n="$1" '$1 == n { sub(/^[^ ]+ /, ""); print; exit }'; }

cmd_add() {
  local dir manifest name
  dir=$(cd "${1:-.}" && pwd)
  manifest="$dir/.claude-plugin/plugin.json"
  if [[ ! -f $manifest ]]; then
    echo "cloc add: no .claude-plugin/plugin.json in $dir" >&2
    exit 1
  fi
  name=$(jq -r '.name // empty' "$manifest")
  if [[ -z $name ]]; then
    echo "cloc add: $manifest has no name" >&2
    exit 1
  fi
  if [[ -n $(path_of "$name") ]]; then
    echo "cloc add: '$name' already registered: $(path_of "$name")" >&2
    exit 1
  fi
  echo "$name $dir" >> "$registry"
  echo "cloc add: $name -> $dir"
}

cmd_delete() {
  local names=("$@") picked name
  if (( ${#names[@]} == 0 )); then
    picked=$(entries | gum filter --no-limit --header 'Delete which plugins? tab marks, enter confirms') || true
    while read -r name _; do
      [[ -n $name ]] && names+=("$name")
    done <<< "$picked"
    if (( ${#names[@]} == 0 )); then
      echo "cloc delete: cancelled"
      exit 1
    fi
  fi
  for name in "${names[@]}"; do
    if [[ -z $(path_of "$name") ]]; then
      echo "cloc delete: unknown plugin '$name'" >&2
      exit 1
    fi
  done
  # The default is No, so an Enter pressed out of habit deletes nothing.
  gum confirm --default=false "Remove ${names[*]} from the registry?" || { echo "cloc delete: cancelled"; exit 1; }
  local tmp
  tmp=$(mktemp "$registry.XXXXXX")
  awk -v drop="${names[*]}" '
    BEGIN { n = split(drop, d, " "); for (i = 1; i <= n; i++) gone[d[i]] = 1 }
    /^#/ || !($1 in gone)
  ' "$registry" > "$tmp"
  mv "$tmp" "$registry"
  echo "cloc delete: removed ${names[*]}"
}

cmd_launch() {
  local names=() claude_args=() picked name dir flags=()
  while (( $# > 0 )); do
    if [[ $1 == -- ]]; then
      shift
      claude_args=("$@")
      break
    fi
    names+=("$1")
    shift
  done

  if (( ${#names[@]} == 0 )); then
    picked=$(entries | gum filter --no-limit --header 'Load which plugins? tab marks, enter confirms') || true
    while read -r name _; do
      [[ -n $name ]] && names+=("$name")
    done <<< "$picked"
    if (( ${#names[@]} == 0 )); then
      echo "cloc: nothing picked"
      exit 1
    fi
  elif [[ ${names[*]} == all ]]; then
    names=()
    while read -r name _; do names+=("$name"); done <<< "$(entries)"
  fi

  for name in "${names[@]}"; do
    dir=$(path_of "$name")
    if [[ -z $dir ]]; then
      echo "cloc: unknown plugin '$name' ($(entries | cut -d' ' -f1 | tr '\n' ' '))" >&2
      exit 1
    fi
    if [[ ! -d $dir ]]; then
      echo "cloc: $name points at a missing directory: $dir" >&2
      exit 1
    fi
    flags+=(--plugin-dir "$dir")
  done

  echo "cloc: local ${names[*]}"
  exec claude "${flags[@]}" ${claude_args[@]+"${claude_args[@]}"}
}

# Installs a plugin the way a user would, from a copy of its marketplace renamed
# <marketplace>-dev, so the real marketplace and its installs stay as they are.
cmd_install_test() {
  local name=${1:-} dir root market
  if [[ -z $name ]]; then
    name=$(entries | gum filter --header 'Install-test which plugin?' | cut -d' ' -f1) || true
    [[ -n $name ]] || { echo "cloc install-test: nothing picked"; exit 1; }
  fi
  dir=$(path_of "$name")
  [[ -n $dir ]] || { echo "cloc install-test: unknown plugin '$name'" >&2; exit 1; }

  root=$dir
  while [[ $root != / && ! -f $root/.claude-plugin/marketplace.json ]]; do root=$(dirname "$root"); done
  if [[ $root == / ]]; then
    echo "cloc install-test: no .claude-plugin/marketplace.json above $dir" >&2
    exit 1
  fi
  market=$(jq -r '.name' "$root/.claude-plugin/marketplace.json")
  # Globals: the EXIT trap runs after this function's locals are gone.
  dev="$market-dev"

  tmp=$(mktemp -d "${TMPDIR:-/tmp}/cloc-install-test.XXXXXX")
  # Removing the dev marketplace also uninstalls the plugin and deletes its options and data.
  trap 'claude plugin marketplace remove "$dev" >/dev/null 2>&1 || true; rm -rf "$tmp" "$HOME/.claude/plugins/cache/$dev"; echo "cloc install-test: removed $dev"' EXIT

  rsync -a --exclude .git --exclude node_modules "$root/" "$tmp/"
  jq --arg n "$dev" '.name = $n' "$root/.claude-plugin/marketplace.json" > "$tmp/.claude-plugin/marketplace.json"
  claude plugin marketplace remove "$dev" >/dev/null 2>&1 || true
  claude plugin marketplace add "$tmp" >/dev/null

  echo "cloc install-test: opening the install for $name@$dev; $dev is removed when Claude exits"
  claude "/plugin install $name@$dev"
}

case "${1:-}" in
  add) shift; cmd_add "$@" ;;
  install-test) shift; cmd_install_test "$@" ;;
  delete) shift; cmd_delete "$@" ;;
  list) entries ;;
  *) cmd_launch "$@" ;;
esac
