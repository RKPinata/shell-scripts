#!/bin/bash

# Push the current branch to origin with upstream tracking.
#
# For resolve/merge_master_to_* branches (created by gmbr), also open a draft PR
# back against the branch master was merged into, and print its URL.

trap "echo -e '\n🚪 Exiting...'; exit 1" SIGINT

# Get current branch and push with upstream set to origin
current_branch=$(git branch --show-current)

if [[ -z "$current_branch" ]]; then
  echo "❌ Not on a branch (detached HEAD?). Exiting."
  exit 1
fi

echo "git push --set-upstream origin $current_branch"
echo ""
git push --set-upstream origin "$current_branch" || exit 1

# --- Draft PR for resolve branches ------------------------------------------

# gmbr builds these as resolve/merge_master_to_<sanitized parent>. Accept - as
# well as _ in the prefix so hand-made branches match too.
if [[ ! "$current_branch" =~ ^resolve/merge[-_]master[-_]to[-_](.+)$ ]]; then
  exit 0
fi
raw_parent="${BASH_REMATCH[1]}"

if ! command -v gh &>/dev/null; then
  echo ""
  echo "⚠️  gh is not installed — skipping draft PR."
  exit 0
fi

# Sanitize the same way gum_create_branch.sh does.
sanitize() {
  local s="${1//\//_}"
  echo "${s//-/_}"
}

# Compare on the sanitized form: the suffix may use - or _ as its separator, and
# either could stand for a / or a - in the real branch name.
sanitized_parent=$(sanitize "$raw_parent")

# The parent is usually a flight branch, and the suffix sometimes drops that
# prefix (…to-integration-google-calendar → flight/integration-google-calendar),
# so accept the implied-flight form too.
sanitized_flight="flight_${sanitized_parent}"

# All known branches, flight/* first, newest first — same ordering gmbr uses.
list_branches() {
  {
    git for-each-ref --sort=-committerdate refs/heads/ --format="%(refname:short)"
    git for-each-ref --sort=-committerdate refs/remotes/origin/ --format="%(refname:short)" |
      sed 's|^origin/||'
  } | grep -v '^HEAD$' | grep -v "^${current_branch}$" | awk '!seen[$0]++' |
    awk '/^flight\//{f=f $0 "\n"; next} {o=o $0 "\n"} END{printf "%s%s", f, o}'
}

# 1. Preferred: the parent branch gmbr recorded at creation time.
base_branch=$(git config --get "branch.${current_branch}.parentBranch")

# 2. Fallback (branches created before that config was written): find every
#    known branch whose sanitized name matches the suffix. Ambiguity is real
#    here — flight_a_b could be flight/a-b or flight-a/b — so ask when it is.
if [[ -z "$base_branch" ]]; then
  candidates=()
  while IFS= read -r branch; do
    [[ -z "$branch" ]] && continue
    s=$(sanitize "$branch")
    if [[ "$s" == "$sanitized_parent" || "$s" == "$sanitized_flight" ]]; then
      candidates+=("$branch")
    fi
  done < <(list_branches)

  # list_branches puts flight/* first, so a flight branch wins any tie.
  if [[ ${#candidates[@]} -eq 1 ]]; then
    base_branch="${candidates[0]}"
  elif [[ ${#candidates[@]} -gt 1 ]]; then
    if command -v gum &>/dev/null; then
      base_branch=$(printf "%s\n" "${candidates[@]}" |
        gum filter --header "📂 Multiple branches match '${raw_parent}' — pick the PR base") || exit 1
    else
      base_branch="${candidates[0]}"
      echo "⚠️  Multiple branches match; using '${base_branch}'."
    fi
  else
    # Nothing matched — don't dead-end, just ask (flight/* listed first).
    echo ""
    echo "⚠️  No branch matches '${raw_parent}'."
    if command -v gum &>/dev/null; then
      base_branch=$(list_branches |
        gum filter --header "📂 Pick the PR base branch (flight/* first)") || exit 1
    else
      echo "   Open the PR manually, or set:"
      echo "   git config branch.${current_branch}.parentBranch <branch>"
      exit 0
    fi
  fi

  [[ -z "$base_branch" ]] && exit 1

  # Cache it so the next push on this branch skips all of the above.
  git config "branch.${current_branch}.parentBranch" "$base_branch"
fi

if ! git ls-remote --exit-code --heads origin "$base_branch" &>/dev/null; then
  echo ""
  echo "⚠️  Base branch '${base_branch}' does not exist on origin — skipping draft PR."
  exit 0
fi

echo ""

# Don't try to create a second PR for the same branch.
existing_pr=$(gh pr view "$current_branch" --json url --jq .url 2>/dev/null)
if [[ -n "$existing_pr" ]]; then
  echo "ℹ️  PR already exists:"
  echo "$existing_pr"
  exit 0
fi

echo "📬 Opening draft PR: ${current_branch} → ${base_branch}"
pr_url=$(gh pr create \
  --draft \
  --base "$base_branch" \
  --head "$current_branch" \
  --title "chore: merge master to ${base_branch}" \
  --body "") || exit 1

echo ""
echo "$pr_url"
