#!/usr/bin/env zsh

# Shell integration for git scripts.
# Sourced from ~/.zshrc via install.sh.
# Defines: gmcm, gmbr, gpso, showlocalhost, cd-

source "${0:A:h}/shared.zsh"

# Clear any pre-existing aliases so the function definitions below
# do not collide with them.
unalias gmcm gmbr gpso showlocalhost 2>/dev/null

# Run in a subshell (not sourced): these scripts call `exit`, which would
# otherwise terminate the parent shell. None of them mutate shell state.
gmcm() { bash "${__SCRIPTS_ROOT}/gum_commit.sh" }
gmbr() { bash "${__SCRIPTS_ROOT}/gum_create_branch.sh" }
gpso() { bash "${__SCRIPTS_ROOT}/git_push_set_origin.sh" }
showlocalhost() { bash "${__SCRIPTS_ROOT}/gum_local_servers.sh" "$@" }

# `cd- <name>` jumps to a target listed in config/shell/cd-targets.
# `cd- add` picks a directory and appends it there. `cd- delete` removes one.
__CD_TARGETS_FILE="${__SCRIPTS_ROOT}/config/shell/cd-targets"
__cd_targets() { grep -v '^#' "$__CD_TARGETS_FILE" }
cd-() {
  case $1 in
    add)
      bash "${__SCRIPTS_ROOT}/config/shell/cd_add.sh"
      return ;;
    delete)
      bash "${__SCRIPTS_ROOT}/config/shell/cd_delete.sh" "${@:2}"
      return ;;
  esac
  local name dir
  while read -r name dir; do
    if [[ $name == "$1" ]]; then
      cd "$dir"
      return
    fi
  done < <(__cd_targets)
  print -u2 "cd-: unknown target '$1' ($(__cd_targets | cut -d' ' -f1 | tr '\n' ' ')add delete)"
  return 1
}
_cd-() {
  local -a items
  local name dir
  while read -r name dir; do items+=("$name:$dir"); done < <(__cd_targets)
  if (( CURRENT >= 3 )) && [[ $words[2] == delete ]]; then
    _describe 'target to delete' items
    return
  fi
  (( CURRENT == 2 )) || return
  items=("add:pick a directory and add it as a target"
         "delete:remove a target" $items)
  _describe 'target' items
}
compdef _cd- cd-
