#!/usr/bin/env bash
# `cd- delete [name...]`: remove targets from cd-targets. With no names, pick
# any number with gum. Only the entries go; the directories are untouched.
set -euo pipefail

targets="$(dirname "$0")/cd-targets"

names=("$@")
if (( ${#names[@]} == 0 )); then
  picked=$(grep -v '^#' "$targets" |
    gum filter --no-limit --header 'Delete which targets? tab marks, enter confirms') || true
  while read -r name _; do
    [[ -n $name ]] && names+=("$name")
  done <<< "$picked"
  if (( ${#names[@]} == 0 )); then
    echo "cd- delete: cancelled"
    exit 1
  fi
fi

lines=()
for name in "${names[@]}"; do
  line=$(grep "^$name " "$targets" || true)
  if [[ -z $line ]]; then
    echo "cd- delete: unknown target '$name'" >&2
    exit 1
  fi
  lines+=("$line")
done

printf '  %s\n' "${lines[@]}"
# The default is No, so an Enter pressed out of habit deletes nothing.
gum confirm --default=false "Delete ${#names[@]} target(s)?" || { echo "cd- delete: cancelled"; exit 1; }

tmp=$(mktemp "$targets.XXXXXX")
awk -v drop="${names[*]}" '
  BEGIN { n = split(drop, d, " "); for (i = 1; i <= n; i++) gone[d[i]] = 1 }
  /^#/ || !($1 in gone)
' "$targets" > "$tmp"
mv "$tmp" "$targets"
echo "cd- delete: removed ${names[*]}"
