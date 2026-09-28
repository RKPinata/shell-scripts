#!/usr/bin/env bash
# `cd- add`: browse to a directory in yazi, confirm it, name it, and append it
# to cd-targets. In yazi, `q` picks the directory you are in and `Q` cancels.
set -euo pipefail

targets="$(dirname "$0")/cd-targets"

cwd_file=$(mktemp -t cd-add-cwd.XXXXXX)
trap 'rm -f "$cwd_file"' EXIT

echo "cd- add: browse to the directory, then press q to pick it or Q to cancel."
yazi "$HOME/Repo" --cwd-file="$cwd_file"

# yazi leaves the file empty when it quits with Q.
dir=$(cat "$cwd_file")
if [[ -z $dir ]]; then
  echo "cd- add: cancelled"
  exit 1
fi

# The default is No, so an Enter pressed out of habit adds nothing.
gum confirm --default=false "Add $dir?" || { echo "cd- add: cancelled"; exit 1; }

name=$(gum input --header "Name for $dir" --value "$(basename "$dir")") || exit 1

if [[ ! $name =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "cd- add: name must be letters, digits, '.', '_' or '-'" >&2
  exit 1
fi
if [[ $name == add || $name == delete ]]; then
  echo "cd- add: '$name' is a cd- command" >&2
  exit 1
fi
if grep -q "^$name " "$targets"; then
  echo "cd- add: '$name' already exists: $(grep "^$name " "$targets" | cut -d' ' -f2-)" >&2
  exit 1
fi

echo "$name $dir" >> "$targets"
echo "cd- $name -> $dir"
