#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="/Users/danish/Repo/respond-io-web"
INSTRUCTION_FILE="/Users/danish/scripts/linear/bugfix-prompt.md"
BASE_BRANCH_FALLBACK="AI_DECIDE_BASE_BRANCH"
TARGET_BRANCH_FALLBACK="AI_DECIDE_BRANCH_NAME"

# 0: launch Claude
# 1: stop before Claude launches (for testing)
STOP_FOR_TESTING=0

# Populated by argument parsing in run_script().
ISSUE_IDENTIFIER=""
LINEAR_BRANCH_NAME=""
LINEAR_PROMPT_TEXT=""
LINEAR_PROJECT_NAME_ARG=""
LINEAR_PULL_REQUEST_COMMENT_ID_ARG=""

usage() {
  cat <<'EOF'
Usage: run-claude-remote.sh --issue <identifier> --branch <branch> --project <name> --pull-request-comment-id <id> --prompt <prompt>
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

trim() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

resolve_project_name() {
  local arg_value env_value
  arg_value="$(trim "${LINEAR_PROJECT_NAME_ARG:-}")"
  env_value="$(trim "${LINEAR_PROJECT_NAME:-}")"

  if [ -n "$arg_value" ]; then
    printf '%s' "$arg_value"
    return 0
  fi

  printf '%s' "$env_value"
}

# Reject empty, null-like, or un-interpolated template values from Linear.
normalize_branch_value() {
  local value
  value="$(trim "${1:-}")"
  case "$value" in
    ""|"null"|"undefined"|"{{issue.branchName}}")
      return 0
      ;;
    *)
      printf '%s' "$value"
      ;;
  esac
}

slugify_text() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}

# Produce progressively shorter slug candidates by stripping trailing
# quarter (q1-q4), year (2024), or numeric segments. This allows fuzzy
# matching against flight branches whose names omit those suffixes.
# Example: "inbox-q2-2025" → "inbox-q2-2025", "inbox-q2", "inbox".
project_slug_candidates() {
  local slug shortened
  slug="$(slugify_text "${1:-}")"

  [ -n "$slug" ] || return 0
  printf '%s\n' "$slug"

  shortened="$slug"
  while printf '%s' "$shortened" | grep -Eq -- '-(q[1-4]|20[0-9]{2}|[0-9]{1,4})$'; do
    shortened="${shortened%-*}"
    [ -n "$shortened" ] || break
    printf '%s\n' "$shortened"
  done
}

collect_remote_flight_branches() {
  git -C "$REPO_DIR" for-each-ref --format='%(refname:short)' refs/remotes/origin/flight \
    refs/remotes/origin/flight/* 2>/dev/null \
    | sed 's#^origin/##' \
    | sort -u
}

# Determine the base branch by matching project/prompt context against
# remote flight/* branches. Returns the fallback sentinel when no match
# is found, signalling Claude to decide at runtime.
infer_base_branch() {
  local project_name prompt_text candidates candidate branch best_branch
  local best_score=0

  project_name="$(resolve_project_name)"
  prompt_text="$(trim "$LINEAR_PROMPT_TEXT")"
  candidates=""

  # --- Phase 1: Collect candidate slugs from project name and prompt ---

  if [ -n "$project_name" ]; then
    candidates="${candidates}"$'\n'"$(project_slug_candidates "$project_name")"
  fi

  if [ -n "$prompt_text" ]; then
    candidates="${candidates}"$'\n'"$(printf '%s' "$prompt_text" \
      | tr '[:upper:]' '[:lower:]' \
      | grep -Eo 'flight/[a-z0-9._/-]+' || true)"
  fi

  # --- Phase 2: Match candidates against remote flight branches ---
  # Priority: exact match > flight/ prefix match > longest substring match.

  while IFS= read -r branch; do
    [ -n "$branch" ] || continue

    while IFS= read -r candidate; do
      [ -n "$candidate" ] || continue

      # Exact match — return immediately.
      if [ "$candidate" = "$branch" ]; then
        printf '%s' "$branch"
        return 0
      fi

      # Candidate matches the branch without its flight/ prefix.
      if [ "$branch" = "flight/$candidate" ]; then
        printf '%s' "$branch"
        return 0
      fi

      # Substring match — keep the longest candidate as best guess.
      if printf '%s' "$branch" | grep -Fq "$candidate"; then
        if [ "${#candidate}" -gt "$best_score" ]; then
          best_score="${#candidate}"
          best_branch="$branch"
        fi
      fi
    done <<EOF
$(printf '%s\n' "$candidates" | sed '/^$/d' | sort -u)
EOF
  done <<EOF
$(collect_remote_flight_branches)
EOF

  # --- Phase 3: Return best substring match or fallback ---

  if [ -n "${best_branch:-}" ]; then
    printf '%s' "$best_branch"
    return 0
  fi

  printf '%s' "$BASE_BRANCH_FALLBACK"
}

# Derive a conventional branch prefix (fix/, feat/, refactor/) from
# the Linear project name and prompt keywords.
infer_prefix() {
  local haystack
  haystack="$(printf '%s %s' "${LINEAR_PROJECT_NAME:-}" "$LINEAR_PROMPT_TEXT" | tr '[:upper:]' '[:lower:]')"

  case "$haystack" in
    *bug*)               printf 'fix'      ;;
    *feature*)           printf 'feat'     ;;
    *tech*improvement*)  printf 'refactor' ;;
    *product*improvement*) printf 'feat'   ;;
    *)                   return 0          ;;
  esac
}

infer_target_branch() {
  local normalized_branch prefix suffix
  normalized_branch="$(normalize_branch_value "$LINEAR_BRANCH_NAME")"
  if [ -n "$normalized_branch" ]; then
    printf '%s' "$normalized_branch"
    return 0
  fi

  prefix="$(infer_prefix)"
  suffix="$(slugify_text "$ISSUE_IDENTIFIER")"

  if [ -n "$prefix" ] && [ -n "$suffix" ]; then
    printf '%s/%s' "$prefix" "$suffix"
    return 0
  fi

  printf '%s' "$TARGET_BRANCH_FALLBACK"
}

# Open a new cmux workspace and run claude with the given prompt.
# Usage: launch_claude_in_cmux <workspace_dir> <issue_slug> <prompt>
launch_claude_in_cmux() {
  require_command cmux
  
  local workspace_dir="$1" slug="$2" prompt="$3"
  local workspace_name="claude: ${slug}"
  local prompt_file="/tmp/claude-prompt-${slug}.txt"

  printf '%s' "$prompt" > "$prompt_file"

  cmux new-workspace \
    --cwd "$workspace_dir" \
    --command "claude --dangerously-skip-permissions \"\$(cat '${prompt_file}')\""

  cmux rename-workspace "$workspace_name"

  printf 'Launched in cmux workspace: %s\n' "$workspace_name"
}

build_prompt() {
  local instruction_text project_name
  instruction_text="$(cat "$INSTRUCTION_FILE")"
  project_name="$(resolve_project_name)"

  cat <<EOF

Repository path hint: $REPO_DIR
Linear issue: $ISSUE_IDENTIFIER
Linear project: $project_name
Base branch hint: $BASE_BRANCH
Target branch hint: $TARGET_BRANCH

Linear prompt/context:
$LINEAR_PROMPT_TEXT

Execution instructions:
$instruction_text
EOF
}

###############################################################################
# SCRIPT EXECUTION STARTS HERE
# Everything above this line is function declaration and configuration.
# Everything below this line runs when Linear launches the script.
###############################################################################

run_script() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --issue)
        ISSUE_IDENTIFIER="${2:-}"
        shift 2
        ;;
      --branch)
        LINEAR_BRANCH_NAME="${2:-}"
        shift 2
        ;;
      --project)
        LINEAR_PROJECT_NAME_ARG="${2:-}"
        shift 2
        ;;
      --pull-request-comment-id)
        LINEAR_PULL_REQUEST_COMMENT_ID_ARG="${2:-}"
        shift 2
        ;;
      --prompt)
        LINEAR_PROMPT_TEXT="${2:-}"
        shift 2
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        printf 'Unknown argument: %s\n' "$1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done

  if [ -z "$ISSUE_IDENTIFIER" ]; then
    printf 'Missing required --issue argument\n' >&2
    usage >&2
    exit 1
  fi

  require_command git

  if [ ! -d "$REPO_DIR/.git" ] && [ ! -f "$REPO_DIR/.git" ]; then
    printf 'Repository not found at %s\n' "$REPO_DIR" >&2
    exit 1
  fi

  if [ ! -r "$INSTRUCTION_FILE" ]; then
    printf 'Instruction file is missing or unreadable: %s\n' "$INSTRUCTION_FILE" >&2
    exit 1
  fi

  BASE_BRANCH="$(infer_base_branch)"
  TARGET_BRANCH="$(infer_target_branch)"
  REMOTE_PROMPT="$(build_prompt)"

  printf 'Linear issue: %s\n' "$ISSUE_IDENTIFIER"
  printf 'Base branch: %s\n' "$BASE_BRANCH"
  printf 'Target branch: %s\n' "$TARGET_BRANCH"
  printf 'Instruction file: %s\n' "$INSTRUCTION_FILE"

  ###############################################################################
  # LAUNCH CLAUDE IN A NEW CMUX WORKSPACE
  ###############################################################################

  if [ "$STOP_FOR_TESTING" -eq 1 ]; then
    printf '\nPrompt preview:\n'
    printf '%s\n' "$REMOTE_PROMPT"
    exit 0
  fi

  launch_claude_in_cmux "$REPO_DIR" "$(slugify_text "$ISSUE_IDENTIFIER")" "$REMOTE_PROMPT"

}

run_script "$@"