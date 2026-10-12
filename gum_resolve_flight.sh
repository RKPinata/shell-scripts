#!/usr/bin/env bash

# Merge master into a flight branch on a resolve/ branch in a chosen worktree,
# then start Claude in this terminal to resolve the merge.
#
# resolve_flight_finish.sh commits the merge, runs gpso and switches the
# worktree back to the branch it was on.

set -euo pipefail

REPO_DIR="/Users/danish/Repo/respond-io-web"
SCRIPTS_DIR="/Users/danish/scripts"
PROMPT_FILE="$SCRIPTS_DIR/resolve-flight-prompt.md"
FINISH_SCRIPT="$SCRIPTS_DIR/resolve_flight_finish.sh"

trap 'echo -e "\n🚪 Exiting..."; exit 1' SIGINT

die() {
  printf '❌ %s\n' "$*" >&2
  exit 1
}

# Runs git in the chosen worktree. Refs are shared by every worktree.
g() {
  git -C "$WT" "$@"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

is_ancestor() {
  g merge-base --is-ancestor "$1" "$2"
}

# Path of the worktree that has <branch> checked out, or nothing.
worktree_for_branch() {
  git -C "$REPO_DIR" worktree list --porcelain | awk -v ref="refs/heads/$1" '
    /^worktree / { path = substr($0, 10) }
    $0 == "branch " ref { print path; exit }
  '
}

# Prints the operation git is in the middle of in <worktree>, or nothing.
operation_in_progress() {
  local git_dir marker
  git_dir="$(git -C "$1" rev-parse --absolute-git-dir)"
  for marker in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply BISECT_LOG; do
    if [ -e "$git_dir/$marker" ]; then
      printf '%s' "$marker"
      return 0
    fi
  done
  return 0
}

has_tracked_changes() {
  [ -n "$(git -C "$1" status --porcelain --untracked-files=no)" ]
}

# Stops unless <worktree> has no operation in progress and no tracked changes.
require_clean_worktree() {
  local path="$1" label="$2" op
  op="$(operation_in_progress "$path")"
  [ -z "$op" ] || die "$label has an operation in progress ($op). Finish or abort it first."
  if has_tracked_changes "$path"; then
    git -C "$path" status --short --untracked-files=no >&2
    die "$label has uncommitted changes. Commit or stash them first."
  fi
}

# Exits unless the answer is Yes.
confirm_or_stop() {
  local rc=0
  gum confirm "$@" || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "🛑 Stopped."
    exit 1
  fi
}

# Fast-forwards local <branch> to origin/<branch>, creating it when missing.
# Stops when the local branch has commits origin does not.
sync_branch() {
  local branch="$1" local_sha remote_sha branch_worktree
  remote_sha="$(g rev-parse "refs/remotes/origin/$branch")"

  if ! g show-ref --verify --quiet "refs/heads/$branch"; then
    g branch --quiet --track "$branch" "origin/$branch"
    return 0
  fi

  local_sha="$(g rev-parse "refs/heads/$branch")"
  [ "$local_sha" != "$remote_sha" ] || return 0

  if is_ancestor "$remote_sha" "$local_sha"; then
    die "Local $branch has commits that are not on origin. Push them first."
  elif ! is_ancestor "$local_sha" "$remote_sha"; then
    die "Local $branch and origin/$branch have diverged"
  fi

  branch_worktree="$(worktree_for_branch "$branch")"
  if [ -n "$branch_worktree" ]; then
    # git refuses to move a branch that a worktree has checked out, so
    # fast-forward it inside that worktree.
    require_clean_worktree "$branch_worktree" "$branch_worktree ($branch)"
    git -C "$branch_worktree" merge --ff-only --quiet "refs/remotes/origin/$branch" \
      || die "Fast-forward of $branch in $branch_worktree failed"
  else
    g update-ref "refs/heads/$branch" "$remote_sha" "$local_sha" \
      || die "Fast-forward of $branch failed"
  fi

  [ "$(g rev-parse "refs/heads/$branch")" = "$remote_sha" ] \
    || die "$branch is not at origin/$branch after update"
}

# --- Preflight --------------------------------------------------------------

for cmd in git gum gh claude; do
  require_command "$cmd"
done
[ -r "$PROMPT_FILE" ] || die "Prompt file missing: $PROMPT_FILE"
[ -r "$FINISH_SCRIPT" ] || die "Finish script missing: $FINISH_SCRIPT"
git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1 || die "Not a git repository: $REPO_DIR"

# --- Pick the worktree ------------------------------------------------------

# "<label>\t<path>\t<branch>" for each worktree with a branch checked out, in
# git's order. Labels follow cd-tree and del-tree: the folder name, with
# "(main tree)" on the main worktree, and the full path when two worktrees
# share a folder name.
worktrees="$(git -C "$REPO_DIR" worktree list --porcelain | awk '
  /^worktree / { path = substr($0, 10); branch = "" }
  /^branch /   { branch = substr($0, 19) }
  /^prunable/  { path = "" }
  /^$/ && path != "" && branch != "" { print path "\t" branch; path = "" }
  END { if (path != "" && branch != "") print path "\t" branch }
' | awk -F '\t' -v main="$REPO_DIR" '
  {
    path[NR] = $1; branch[NR] = $2
    name[NR] = $1; sub(/.*\//, "", name[NR])
    count[name[NR]]++
  }
  END {
    for (i = 1; i <= NR; i++) {
      label = name[i]
      if (path[i] == main) label = label " (main tree)"
      else if (count[name[i]] > 1) label = path[i]
      print label "\t" path[i] "\t" branch[i]
    }
  }
')"
[ -n "$worktrees" ] || die "No worktrees with a branch checked out"

wt_choice="$(printf '%s\n' "$worktrees" | cut -f1 | gum filter --header "Select a git worktree to resolve in")" || exit 1
[ -n "$wt_choice" ] || exit 1
WT="$(printf '%s\n' "$worktrees" | awk -F '\t' -v l="$wt_choice" '$1 == l { print $2; exit }')"
RETURN_BRANCH="$(printf '%s\n' "$worktrees" | awk -F '\t' -v l="$wt_choice" '$1 == l { print $3; exit }')"
[ -d "$WT" ] && [ -n "$RETURN_BRANCH" ] || die "Could not read the worktree choice: $wt_choice"

require_clean_worktree "$WT" "$WT"

master_worktree="$(worktree_for_branch master)"
if [ -n "$master_worktree" ] && [ "$master_worktree" != "$WT" ]; then
  require_clean_worktree "$master_worktree" "$master_worktree (master)"
fi

UNTRACKED="$(g ls-files --others --exclude-standard)"
if [ -n "$UNTRACKED" ]; then
  echo "Untracked files in $WT:"
  sed 's/^/  /' <<<"$UNTRACKED"
  confirm_or_stop --default=false "Continue? They stay out of the merge commit."
fi

echo "🔄 Fetching origin..."
g fetch --prune --quiet origin || die "git fetch failed"

# --- Pick the flight branch -------------------------------------------------

flights="$(g for-each-ref --sort=-committerdate --format='%(refname:lstrip=3)' refs/remotes/origin/flight/)"
[ -n "$flights" ] || die "No flight/ branches on origin"

choose_flags=()
if printf '%s\n' "$flights" | grep -qxF "$RETURN_BRANCH"; then
  choose_flags=(--selected "$RETURN_BRANCH")
fi
FLIGHT="$(printf '%s\n' "$flights" \
  | gum choose ${choose_flags[@]+"${choose_flags[@]}"} --header "✈️  Flight branch to sync with master")" || exit 1
[ -n "$FLIGHT" ] || exit 1

# --- Update master and the flight branch ------------------------------------

sync_branch master
sync_branch "$FLIGHT"
MASTER_SHA="$(g rev-parse refs/heads/master)"
FLIGHT_SHA="$(g rev-parse "refs/heads/$FLIGHT")"

if is_ancestor "$MASTER_SHA" "$FLIGHT_SHA"; then
  echo "✅ $FLIGHT already contains master. Nothing to merge."
  exit 0
fi

# --- Resolve branch ---------------------------------------------------------

# Same name gmbr gives a resolve branch.
sanitized="${FLIGHT//\//_}"
sanitized="${sanitized//-/_}"
RESOLVE="resolve/merge_master_to_${sanitized}"

# A resolve branch left from an earlier round is reused only when the flight
# already contains all of it. Anything else is unfinished work.
checkout_flag="-b"
if g show-ref --verify --quiet "refs/heads/$RESOLVE"; then
  resolve_worktree="$(worktree_for_branch "$RESOLVE")"
  [ -z "$resolve_worktree" ] || die "$RESOLVE is checked out in $resolve_worktree"
  is_ancestor "refs/heads/$RESOLVE" "$FLIGHT_SHA" \
    || die "Local $RESOLVE has commits that are not in $FLIGHT. Merge its PR or delete the branch first."
  checkout_flag="-B"
fi
if g show-ref --verify --quiet "refs/remotes/origin/$RESOLVE"; then
  is_ancestor "refs/remotes/origin/$RESOLVE" "$FLIGHT_SHA" \
    || die "origin/$RESOLVE has commits that are not in $FLIGHT. Merge its PR or delete the branch first."
fi

behind="$(g rev-list --count "$FLIGHT_SHA..$MASTER_SHA")"
echo ""
echo "worktree: $WT (on $RETURN_BRANCH)"
echo "master:   ${MASTER_SHA:0:10}"
echo "flight:   $FLIGHT (${FLIGHT_SHA:0:10}), $behind commit(s) behind master"
echo "branch:   $RESOLVE"
[ "$checkout_flag" = "-B" ] && echo "          (existing branch is already in $FLIGHT and will be reset)"
echo ""
confirm_or_stop "Create $RESOLVE in this worktree and merge master into it?"

g checkout --quiet --no-track "$checkout_flag" "$RESOLVE" "$FLIGHT_SHA"
g config "branch.${RESOLVE}.parentBranch" "$FLIGHT"
g config "branch.${RESOLVE}.resolveFlightMaster" "$MASTER_SHA"
g config "branch.${RESOLVE}.resolveFlightBase" "$FLIGHT_SHA"
g config "branch.${RESOLVE}.resolveFlightReturn" "$RETURN_BRANCH"

# Undo the branch when the merge never started, so the worktree is back on its
# branch exactly as it was.
rollback() {
  g checkout --quiet "$RETURN_BRANCH" || return
  if [ "$(g rev-parse "refs/heads/$RESOLVE")" = "$FLIGHT_SHA" ]; then
    g branch --quiet -D "$RESOLVE"
  fi
}

# --- Merge ------------------------------------------------------------------

echo ""
echo "🔀 git merge --no-ff --no-commit master"
set +e
g merge --no-ff --no-commit master
merge_rc=$?
set -e

if [ ! -f "$(g rev-parse --absolute-git-dir)/MERGE_HEAD" ]; then
  rollback
  die "git merge did not start (exit $merge_rc). See the output above. Back on $RETURN_BRANCH."
fi
[ "$(g rev-parse MERGE_HEAD)" = "$MASTER_SHA" ] || die "MERGE_HEAD is not master. Inspect $WT by hand."

CONFLICTS="$(g diff --name-only --diff-filter=U)"

if [ -z "$CONFLICTS" ]; then
  echo ""
  echo "✅ No conflicts. The merge is staged and not committed."
  choice="$(gum choose --header "Next step" "Open Claude to review the merge" "Commit and push now")" || exit 1
  if [ "$choice" = "Commit and push now" ]; then
    exec bash "$FINISH_SCRIPT" "$WT"
  fi
else
  echo ""
  echo "⚠️  Conflicted files:"
  sed 's/^/  /' <<<"$CONFLICTS"
fi

# --- Launch Claude ----------------------------------------------------------

echo ""
NOTES="$(gum write --show-help --height 6 \
  --header "Extra instructions for Claude (optional)" \
  --placeholder "e.g. keep the flight's version of the lifecycle store")" || NOTES=""

finish_command="bash $FINISH_SCRIPT '$WT'"

prompt="$(
  cat <<EOF
Worktree: $WT
Flight branch: $FLIGHT at $FLIGHT_SHA
Master: $MASTER_SHA
Resolve branch: $RESOLVE (checked out, merge of master in progress)
Finish command: $finish_command

Conflicted files:
${CONFLICTS:-(none — git merged every file cleanly)}

Untracked files that were here before the merge (never stage these):
${UNTRACKED:-(none)}

Developer notes:
${NOTES:-(none)}

EOF
  cat "$PROMPT_FILE"
)"

echo ""
echo "🤖 Starting Claude in $WT."
echo "   If the session ends early, finish with: $finish_command"
echo ""

cd "$WT"
exec claude --dangerously-skip-permissions "$prompt"
