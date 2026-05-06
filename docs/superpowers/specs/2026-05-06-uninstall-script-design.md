# Uninstall Script Design

**Date:** 2026-05-06
**Scope:** `worktree/uninstall.sh`

## Overview

A companion uninstall script for `worktree/install.sh`. Removes the shell integration block from `~/.zshrc` and optionally uninstalls the `gum` Homebrew dependency.

## Goals

- Remove the `worktree-scripts START/END` block from `~/.zshrc`
- Offer optional removal of the `gum` brew package
- Mirror the structure and style of `install.sh`
- Be idempotent: safe to run multiple times

## Non-Goals

- Does not delete the cloned script files
- Does not remove `git` or `zsh`
- Does not include a dry-run mode

## Design

### File

`worktree/uninstall.sh`

### Shared constants (mirrored from install.sh)

```
SCRIPT_DIR, ZSHRC, MARKER_START, MARKER_END, copy_to_clipboard()
```

### Steps

1. **Idempotency check**
   - If `MARKER_START` is not found in `~/.zshrc`, print "Not installed." and exit 0.

2. **Remove the block**
   - Use `sed` to delete all lines from `MARKER_START` through `MARKER_END` (inclusive).
   - On failure, print an error and exit 1.

3. **Clipboard reminder**
   - Print: "Uninstalled. Restart your shell or run: source ~/.zshrc"
   - Copy `source ~/.zshrc` to clipboard via `copy_to_clipboard`.

4. **Optional gum removal**
   - Prompt: "Remove gum via brew? [y/N]" (default: no)
   - If yes: run `brew uninstall gum`
   - On brew failure: print a warning, do not exit with error (the .zshrc change succeeded)

## Error Handling

| Scenario | Behaviour |
|---|---|
| Block not in .zshrc | Print "Not installed." and exit 0 |
| sed fails | Print error, exit 1 |
| brew uninstall fails | Print warning, exit 0 (partial success) |
| brew not installed but user chose yes | Print warning that brew is unavailable |
