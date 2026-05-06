# Worktree Scripts — Team Sharing Design

**Date:** 2026-05-06
**Status:** Approved

## Overview

Consolidate the three worktree management scripts into a self-contained `worktree/` folder with an installer and README, enabling teammates to set up the tooling with a single command.

## Folder Structure

```
worktree/
├── install.sh              # One-time setup — adds source line to .zshrc
├── shell-integration.zsh   # Defines create-tree, cd-tree, del-tree
├── create_worktree.sh      # Create a new worktree (new or existing branch)
├── delete_worktree.sh      # Select and force-delete worktrees
├── cd_worktree.sh          # cd into a worktree
└── README.md               # Prerequisites, install instructions, usage
```

Scripts are renamed from their `gum_` prefixed originals. The `gum_` prefix is redundant within the `worktree/` folder context.

## File Origins

| New path | Original path |
|---|---|
| `worktree/create_worktree.sh` | `gum_create_worktree.sh` |
| `worktree/delete_worktree.sh` | `gum_delete_worktree.sh` |
| `worktree/cd_worktree.sh` | `gum_cd_worktree.sh` |

## Command Names

| Command | Type | Reason |
|---|---|---|
| `create-tree` | shell function | Must be sourced — `cd`s into the new worktree |
| `cd-tree` | shell function | Must be sourced — changes caller's working directory |
| `del-tree` | direct execution | No shell state changes needed |

## install.sh Logic

The installer executes the following steps in order:

1. **Resolve own location** — `SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"` — works regardless of invocation path.
2. **Validate folder structure** — confirm `create_worktree.sh`, `delete_worktree.sh`, `cd_worktree.sh`, and `shell-integration.zsh` exist relative to `SCRIPT_DIR`. Exit with clear error per missing file.
3. **Check prerequisites** — verify `gum`, `git`, and `zsh` are installed. Exit with error per missing tool.
4. **Check .zshrc exists** — if `~/.zshrc` does not exist, create it as an empty file with a note.
5. **Idempotency check** — grep for the source line in `.zshrc`. If already present, print "already installed" and exit cleanly.
6. **Append source line** — append `source "<absolute-path>/shell-integration.zsh"` to `~/.zshrc`, bracketed by marker comments:
   ```
   # --- worktree-scripts START ---
   source "/absolute/path/to/worktree/shell-integration.zsh"
   # --- worktree-scripts END ---
   ```
7. **Confirm** — print success message and instruct user to run `source ~/.zshrc` or open a new terminal.

Shell options: `set -euo pipefail` at the top. All error exits use clear messages.

## shell-integration.zsh

Resolves the directory at source-time and defines the three commands:

```zsh
__WORKTREE_DIR="${0:A:h}"

create-tree() { source "${__WORKTREE_DIR}/create_worktree.sh"; }
cd-tree()     { source "${__WORKTREE_DIR}/cd_worktree.sh"; }
del-tree()    { "${__WORKTREE_DIR}/delete_worktree.sh" "$@"; }
```

## Prerequisites

- `gum` — interactive TUI prompts
- `git` — worktree operations
- `zsh` — shell environment (assumed for all teammates)

## README.md Contents

- Prerequisites with install links
- Installation: clone repo, run `./worktree/install.sh`
- Commands: `create-tree`, `cd-tree`, `del-tree` with descriptions
- Uninstall: remove the marker block from `.zshrc`

## Assumptions

- Teammates work on the same project (project-specific env files, `app/` layout, `npm ci` bootstrap are retained in `create_worktree.sh`).
- Teammates use `zsh`.
- The cloned repo path varies per user — `install.sh` resolves the absolute path dynamically.

## Out of Scope

- Other scripts in the repo (`gum_commit.sh`, `gum_create_branch.sh`, etc.) are not part of this effort.
- No PATH-based installation — source-line approach was chosen for its clean separation and automatic update propagation.
