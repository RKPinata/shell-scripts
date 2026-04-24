#!/bin/bash

# Function to handle cancellation
cancel_commit() {
  local reason=$1
  echo "❌ $reason"
  exit 0
}

commit() {
  local summary=$1
  local description=$2
  local verify_flag=$3

  if [ -n "$description" ]; then
    COMMIT_COMMAND="git commit -m \"$summary\" -m \"$description\""
  elif [ -n "$verify_flag" ]; then
    COMMIT_COMMAND="git commit -m \"$summary\" $verify_flag"
  else
    COMMIT_COMMAND="git commit -m \"$summary\""
  fi

  echo "$COMMIT_COMMAND" | tee /dev/tty | pbcopy

  eval "$COMMIT_COMMAND"
  exit 0
}

format() {
  local summary=$1
  local description=$2

  # Format and preview the commit message
  echo -e "\n📝 Commit Message Preview:"
  echo -e "----------------------------"
  echo -e "$summary"
  if [ -n "$description" ]; then
    echo -e "\n$description"
  fi
  echo -e "----------------------------\n"
}

# Select commit type
TYPE=$(gum filter --placeholder "Select a commit type" "build" "feat" "fix" "refactor" "docs" "style" "test" "revert" "chore" "deprecate" "perf" "ci" "x-skip")

if [ "$TYPE" = "x-skip" ]; then
  DEFAULT_SUMMARY=""
else
  # Select scope from predefined list
  SCOPE=$(gum filter --placeholder "Select the scope of changes" \
    "lang" "dashboard" "message" "contact" "broadcast" "channel" \
    "report" "snippet" "file" "custom-fields" "respond-ai" "ai-agent" \
    "workflows" "personal-settings" "workspace-settings" \
    "organization-settings" "billing" "ui" "none")
  # Format scope if it's not 'none'
  [ "$SCOPE" != "none" ] && SCOPE="($SCOPE)" || SCOPE=""
  # Prompt for summary
  DEFAULT_SUMMARY="$TYPE$SCOPE:"
fi

SUMMARY=$(gum input --value "$DEFAULT_SUMMARY" --placeholder "Enter a short summary of this change")

# Validate summary is not empty
if [ -z "$SUMMARY" ]; then
  cancel_commit "Commit summary cannot be empty."
fi

format "$SUMMARY" ""
DECISION=$(gum choose "Commit changes" "Add more details" "Commit with no verify" "Cancel commit")

if [ "$DECISION" = "Cancel commit" ]; then
  cancel_commit "Commit cancelled."
elif [ "$DECISION" = "Commit changes" ]; then
  commit "$SUMMARY" ""
elif [ "$DECISION" = "Commit with no verify" ]; then
  commit "$SUMMARY" "" "-n"
fi

# Prompt for detailed description (multi-line) with commit/cancel options below
DESCRIPTION=$(gum write --placeholder "Provide a more detailed description of the changes")

format "$SUMMARY" "$DESCRIPTION"
DECISION=$(gum choose "Commit changes" "Commit with no verify" "Cancel commit")

if [ "$DECISION" = "Cancel commit" ]; then
  cancel_commit "Commit cancelled."
elif [ "$DECISION" = "Commit changes" ]; then
  commit "$SUMMARY" "$DESCRIPTION"
elif [ "$DECISION" = "Commit with no verify" ]; then
  commit "$SUMMARY" "$DESCRIPTION" "-n"
fi
