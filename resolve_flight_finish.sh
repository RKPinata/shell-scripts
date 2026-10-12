#!/usr/bin/env bash

# Commit the master merge that grflight started, push it with gpso (which opens
# the draft PR), then switch the worktree back to the branch it was on.
#
# Usage: resolve_flight_finish.sh [--no-verify] [worktree]
#
# The worktree defaults to the one containing the current directory.
#
# Safe to run again after a failed push: a merge that is already committed is
# checked and pushed without a second commit.

set -euo pipefail

GPSO_SCRIPT="/Users/danish/scripts/git_push_set_origin.sh"

trap 'echo -e "\n🚪 Exiting..."; exit 1' SIGINT

die() {
  printf '❌ %s\n' "$*" >&2
  exit 1
}

no_verify=""
worktree=""
for arg in "$@"; do
  case "$arg" in
    --no-verify) no_verify="--no-verify" ;;
    -*) die "Unknown argument: $arg" ;;
    *)
      [ -z "$worktree" ] || die "Only one worktree argument is allowed"
      worktree="$arg"
      ;;
  esac
done

if [ -n "$worktree" ]; then
  cd "$worktree" || die "No such directory: $worktree"
fi
cd "$(git rev-parse --show-toplevel)" || die "Not inside a git worktree"

GIT_DIR="$(git rev-parse --absolute-git-dir)"

branch="$(git symbolic-ref --quiet --short HEAD)" || die "Detached HEAD"
[[ "$branch" == resolve/merge_master_to_* ]] || die "On '$branch', not a resolve/merge_master_to_* branch"

base="$(git config --get "branch.${branch}.parentBranch")" || die "No parentBranch recorded for $branch"
master_sha="$(git config --get "branch.${branch}.resolveFlightMaster")" \
  || die "$branch was not started by grflight (no resolveFlightMaster recorded)"
base_sha="$(git config --get "branch.${branch}.resolveFlightBase")" \
  || die "$branch was not started by grflight (no resolveFlightBase recorded)"
return_branch="$(git config --get "branch.${branch}.resolveFlightReturn")" \
  || die "$branch was not started by grflight (no resolveFlightReturn recorded)"

for marker in CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply; do
  [ ! -e "$GIT_DIR/$marker" ] || die "Unexpected operation in progress: $marker"
done

if [ -f "$GIT_DIR/MERGE_HEAD" ]; then
  [ "$(git rev-parse HEAD)" = "$base_sha" ] || die "HEAD moved off $base (${base_sha:0:10}) during the merge"
  [ "$(git rev-parse MERGE_HEAD)" = "$master_sha" ] || die "The merge in progress is not of master ${master_sha:0:10}"

  unmerged="$(git diff --name-only --diff-filter=U)"
  if [ -n "$unmerged" ]; then
    sed 's/^/  /' <<<"$unmerged" >&2
    die "Files still unmerged"
  fi

  unstaged="$(git diff --name-only)"
  if [ -n "$unstaged" ]; then
    sed 's/^/  /' <<<"$unstaged" >&2
    die "Tracked files have unstaged changes. Stage or discard them first."
  fi

  markers="$(git diff --cached -U0 HEAD | grep -E '^\+(<<<<<<<|>>>>>>>)( |$)' || true)"
  if [ -n "$markers" ]; then
    git diff --cached --name-only -G'^(<<<<<<<|>>>>>>>)( |$)' HEAD | sed 's/^/  /' >&2
    die "Staged changes contain conflict markers"
  fi

  echo "📝 git commit --no-edit $no_verify"
  git commit --no-edit $no_verify || die "Commit failed. The merge is still in progress."
fi

# The commit must be exactly the merge grflight set up.
[ "$(git rev-list --parents -n 1 HEAD | wc -w | tr -d ' ')" = "3" ] || die "HEAD is not a merge commit"
[ "$(git rev-parse HEAD^1)" = "$base_sha" ] || die "HEAD's first parent is not $base (${base_sha:0:10})"
[ "$(git rev-parse HEAD^2)" = "$master_sha" ] || die "HEAD's second parent is not master ${master_sha:0:10}"

[ -z "$(git status --porcelain --untracked-files=no)" ] || die "Tracked changes left after the commit"

echo ""
bash "$GPSO_SCRIPT" || die "gpso failed. Fix the cause and run this script again."

git config --unset "branch.${branch}.resolveFlightMaster"
git config --unset "branch.${branch}.resolveFlightBase"
git config --unset "branch.${branch}.resolveFlightReturn"

echo ""
git checkout "$return_branch" || die "Pushed, but could not check out $return_branch in $PWD"
echo "✅ $PWD is back on $return_branch."
