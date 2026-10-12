#!/usr/bin/env zsh

# Run: ./worktree/test_delete_worktree.zsh
#
# Each case builds a throwaway repository under a temp root and sources
# delete_worktree.sh against it. `gum` and `trash` are replaced by stubs on
# PATH: the gum stub records the menu it was offered and replies with
# TEST_GUM_CHOOSE, and the trash stub moves paths into TEST_TRASH so the real
# Trash stays out of it.

SCRIPT="${0:A:h}/delete_worktree.sh"
TESTROOT="$(mktemp -d)"; TESTROOT="${TESTROOT:A}"
STUBS="$TESTROOT/stubs"
mkdir -p "$STUBS"
trap 'rm -rf "$TESTROOT"' EXIT

pass=0 fail=0 repo_n=0

# ---------------------------------------------------------------- stubs

cat > "$STUBS/gum" <<'STUB'
#!/usr/bin/env zsh
case "$1" in
  choose)
    cat > "${TEST_MENU_FILE:-/dev/null}"
    [[ -n "${TEST_GUM_CHOOSE:-}" ]] && print -r -- "$TEST_GUM_CHOOSE"
    exit 0
    ;;
  confirm) exit "${TEST_GUM_CONFIRM:-0}" ;;
esac
exit 0
STUB

cat > "$STUBS/trash" <<'STUB'
#!/usr/bin/env zsh
[[ -n "${TEST_TRASH_FAIL:-}" ]] && { print -u2 "stub trash: forced failure"; exit 5 }
mkdir -p "$TEST_TRASH"
for arg in "$@"; do
  [[ "$arg" == -* ]] && continue
  base="${arg:t}"; target="$TEST_TRASH/$base"; n=1
  while [[ -e "$target" ]]; do target="$TEST_TRASH/$base $((n++))"; done
  mv "$arg" "$target" || exit 5
done
exit 0
STUB

chmod +x "$STUBS/gum" "$STUBS/trash"
export PATH="$STUBS:$PATH"

# ----------------------------------------------------------- assertions

ok()    { (( pass++ )); print "  ok    $1" }
notok() { (( fail++ )); print "  FAIL  $1"; [[ -n "${2:-}" ]] && print "        $2" }

assert_eq()       { [[ "$2" == "$3" ]]   && ok "$1" || notok "$1" "want '$3', got '$2'" }
assert_has()      { [[ "$2" == *"$3"* ]] && ok "$1" || notok "$1" "missing '$3'" }
assert_lacks()    { [[ "$2" != *"$3"* ]] && ok "$1" || notok "$1" "unexpected '$3'" }
assert_gone()     { [[ ! -e "$2" ]]      && ok "$1" || notok "$1" "still on disk: $2" }
assert_exists()   { [[ -e "$2" ]]        && ok "$1" || notok "$1" "not on disk: $2" }

# ------------------------------------------------------------- fixtures

# Sets $repo rather than echoing it, so the case counter survives.
new_repo() {
  repo="$TESTROOT/repo$((++repo_n))"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config user.name Test
  print hi > "$repo/README"
  git -C "$repo" add README
  git -C "$repo" commit -qm init >/dev/null
}

add_wt() {  # repo, path, branch
  git -C "$1" worktree add -q -b "$3" "$2"
}

# Echoes the script's output; the directory the caller's shell was left in
# lands in $TEST_PWD_FILE.
run_delete() {  # repo, start_dir
  (
    cd "$2"
    source "$SCRIPT"
    print -r -- "$(pwd -P)" > "$TEST_PWD_FILE"
  ) 2>&1
}

wt_paths() { git -C "$1" worktree list --porcelain | awk '/^worktree /{sub(/^worktree /,"");print}' }

new_case() {
  print "\n$1"
  new_repo
  export TEST_TRASH="$TESTROOT/trash$repo_n"
  export TEST_MENU_FILE="$TESTROOT/menu$repo_n"
  export TEST_PWD_FILE="$TESTROOT/pwd$repo_n"
  export TEST_GUM_CHOOSE="" TEST_GUM_CONFIRM=0
  unset TEST_TRASH_FAIL
}

# ---------------------------------------------------------------- cases

new_case "deletes the selected worktree and keeps its branch"
add_wt "$repo" "$repo/.worktrees/alpha" alpha
TEST_GUM_CHOOSE=alpha
out="$(run_delete "$repo" "$repo")"
assert_gone   "directory removed"            "$repo/.worktrees/alpha"
assert_exists "moved to the trash"           "$TEST_TRASH/alpha"
assert_eq     "admin entry pruned"           "$(wt_paths $repo)" "$repo"
assert_has    "branch kept"                  "$(git -C $repo branch --list alpha)" alpha

new_case "leaves locked worktrees out of the menu and untouched"
add_wt "$repo" "$repo/.worktrees/alpha" alpha
add_wt "$repo" "$repo/.worktrees/beta" beta
git -C "$repo" worktree lock "$repo/.worktrees/beta"
TEST_GUM_CHOOSE=alpha
out="$(run_delete "$repo" "$repo")"
assert_has    "menu offers the open worktree"   "$(cat "$TEST_MENU_FILE")" alpha
assert_lacks  "menu hides the locked worktree"  "$(cat "$TEST_MENU_FILE")" beta
assert_has    "the skip is reported"            "$out" "Skipping locked worktrees"
assert_exists "locked worktree still on disk"   "$repo/.worktrees/beta"
assert_has    "locked worktree still registered" "$(wt_paths $repo)" "$repo/.worktrees/beta"

new_case "disambiguates worktrees that share a basename"
add_wt "$repo" "$repo/.worktrees/dup" dup-a
add_wt "$repo" "$repo/other/dup" dup-b
TEST_GUM_CHOOSE="$repo/.worktrees/dup"
out="$(run_delete "$repo" "$repo")"
assert_has    "menu lists the first by full path"  "$(cat "$TEST_MENU_FILE")" "$repo/.worktrees/dup"
assert_has    "menu lists the second by full path" "$(cat "$TEST_MENU_FILE")" "$repo/other/dup"
assert_gone   "the selected one is deleted"        "$repo/.worktrees/dup"
assert_exists "the namesake survives"              "$repo/other/dup"

new_case "leaves a worktree reached through a symlink"
add_wt "$repo" "$repo/.worktrees/alpha" alpha
ln -sfn "$repo/.worktrees/alpha" "$TESTROOT/link$repo_n"
TEST_GUM_CHOOSE=alpha
out="$(run_delete "$repo" "$TESTROOT/link$repo_n")"
assert_has  "the shell is moved out"  "$out" "Switched to main worktree"
assert_eq   "and lands in the main worktree" "$(cat "$TEST_PWD_FILE")" "$repo"
assert_gone "directory removed"       "$repo/.worktrees/alpha"

new_case "falls back to git when trash fails"
add_wt "$repo" "$repo/.worktrees/alpha" alpha
TEST_GUM_CHOOSE=alpha TEST_TRASH_FAIL=1
out="$(run_delete "$repo" "$repo")"
assert_gone "directory removed anyway" "$repo/.worktrees/alpha"
assert_eq   "admin entry cleared"      "$(wt_paths $repo)" "$repo"

new_case "clears a stale entry left by an interrupted run"
add_wt "$repo" "$repo/.worktrees/alpha" alpha
mv "$repo/.worktrees/alpha" "$TESTROOT/interrupted$repo_n"
out="$(run_delete "$repo" "$repo")"
assert_eq  "stale entry pruned at startup" "$(wt_paths $repo)" "$repo"
assert_has "and the menu is empty"         "$out" "No worktrees found."

new_case "deletes nothing when the confirmation is declined"
add_wt "$repo" "$repo/.worktrees/alpha" alpha
TEST_GUM_CHOOSE=alpha TEST_GUM_CONFIRM=1
out="$(run_delete "$repo" "$repo")"
assert_has    "the abort is reported" "$out" "Aborted."
assert_exists "worktree untouched"    "$repo/.worktrees/alpha"

new_case "deletes nothing when the selection is empty"
add_wt "$repo" "$repo/.worktrees/alpha" alpha
out="$(run_delete "$repo" "$repo")"
assert_has    "the empty selection is reported" "$out" "No worktrees selected."
assert_exists "worktree untouched"              "$repo/.worktrees/alpha"

new_case "never offers the main worktree"
add_wt "$repo" "$repo/.worktrees/alpha" alpha
out="$(run_delete "$repo" "$repo")"
assert_eq "menu holds only the worktree" "$(cat "$TEST_MENU_FILE")" alpha

# ---------------------------------------------------------------- report

print "\n$pass passed, $fail failed"
(( fail == 0 ))
