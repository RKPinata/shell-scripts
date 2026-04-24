#!/bin/bash

# Graceful exit on Ctrl+C
trap 'echo -e "\n❌ Operation cancelled."; exit 1' SIGINT

# Prompt for alias name
alias_name=$(gum input --placeholder "Enter alias name (e.g., myscript)")
if [[ -z "$alias_name" ]]; then
  echo "❌ Alias name is required."
  exit 1
fi

# List scripts in ~/scripts and select with gum filter
scripts_dir="$HOME/scripts"
if [[ ! -d "$scripts_dir" ]]; then
  echo "❌ Scripts directory not found: $scripts_dir"
  exit 1
fi
script_list=$(find "$scripts_dir" -maxdepth 1 -type f -exec basename {} \; | sort)
script_filename=$(echo "$script_list" | gum filter --header "Select script to add as alias")
if [[ -z "$script_filename" ]]; then
  echo "❌ No script selected."
  exit 1
fi

# Build full path to script
script_path="~/scripts/$script_filename"

# Expand tilde to full path
script_full_path=$(eval echo "$script_path")

# Ask how the alias should invoke the script
alias_type=$(gum choose --header "How should this alias run the script?" "Run directly" "Source (for cd, env changes)")
if [[ -z "$alias_type" ]]; then
  echo "❌ No alias type selected."
  exit 1
fi

# Prepare the alias line
if [[ "$alias_type" == "Source (for cd, env changes)" ]]; then
  alias_line="alias $alias_name=\"source $script_path\""
else
  alias_line="alias $alias_name=\"$script_path\""
fi

# Target zshrc file
zshrc_file="$HOME/.zshrc"

# Insert alias line below the "# SCRIPTS" comment
if grep -q "^# SCRIPTS" "$zshrc_file"; then
  awk -v alias_line="$alias_line" '
    /^# SCRIPTS/ {
      print;
      print alias_line;
      next
    }
    { print }
  ' "$zshrc_file" > "${zshrc_file}.tmp" && mv "${zshrc_file}.tmp" "$zshrc_file"
  echo "✅ Alias added to .zshrc."
else
  echo "❌ '# SCRIPTS' comment not found in .zshrc. Please add it manually."
  exit 1
fi

# Prompt to set executable permissions
if gum confirm "Do you want to make the script executable (chmod +x)?"; then
  chmod +x "$script_full_path" && echo "🔓 Script is now executable."
else
  echo "⚠️ Skipped changing permissions."
fi