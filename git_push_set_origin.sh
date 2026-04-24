#!/bin/bash

# Get current branch and push with upstream set to origin
current_branch=$(git branch --show-current)
echo "git push --set-upstream origin $current_branch"
echo ""
git push --set-upstream origin "$current_branch"
