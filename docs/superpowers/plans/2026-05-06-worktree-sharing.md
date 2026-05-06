# Worktree Scripts Team Sharing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate the three worktree scripts into a self-contained `worktree/` folder with an installer, shell integration, and README so teammates can set up with one command.

**Architecture:** Scripts are moved and renamed into `worktree/`. A `shell-integration.zsh` file defines the three commands (`create-tree`, `cd-tree`, `del-tree`). An `install.sh` validates prerequisites, resolves its own absolute path, and appends a single source line to `~/.zshrc`.

**Tech Stack:** Bash, Zsh, git, gum

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `worktree/create_worktree.sh` | Move from `gum_create_worktree.sh` | Create worktree (new or existing branch) |
| `worktree/delete_worktree.sh` | Move from `gum_delete_worktree.sh` | Select and force-delete worktrees |
| `worktree/cd_worktree.sh` | Move from `gum_cd_worktree.sh` | cd into a worktree |
| `worktree/shell-integration.zsh` | Create | Define `create-tree`, `cd-tree`, `del-tree` commands |
| `worktree/install.sh` | Create | One-time `.zshrc` wiring with prerequisite checks |
| `worktree/README.md` | Create | Prerequisites, install, usage, uninstall docs |

---

### Task 1: Move and rename scripts into worktree/

**Files:**
- Move: `gum_create_worktree.sh` → `worktree/create_worktree.sh`
- Move: `gum_delete_worktree.sh` → `worktree/delete_worktree.sh`
- Move: `gum_cd_worktree.sh` → `worktree/cd_worktree.sh`

- [ ] **Step 1: Create the worktree/ directory**

```bash
mkdir -p worktree
```

- [ ] **Step 2: Move and rename the three scripts**

```bash
git mv gum_create_worktree.sh worktree/create_worktree.sh
git mv gum_delete_worktree.sh worktree/delete_worktree.sh
git mv gum_cd_worktree.sh worktree/cd_worktree.sh
```

- [ ] **Step 3: Update internal path references in cd_worktree.sh**

`worktree/cd_worktree.sh` lines 4, 13, 14 contain old path references. Update the usage comment block (lines 3–6) to:

```bash
# Usage:
#   source cd_worktree.sh
#   or install via: ./install.sh
```

Update the source guard error messages (lines 13–14) to:

```bash
  echo "Usage: source cd_worktree.sh" >&2
  echo "       or install via: ./worktree/install.sh" >&2
```

- [ ] **Step 4: Verify scripts are present and executable**

```bash
ls -la worktree/*.sh
```

Expected: three `.sh` files in `worktree/`.

- [ ] **Step 5: Commit**

```bash
git add worktree/
git commit -m "refactor: move worktree scripts into worktree/ folder

Renamed from gum_* prefix. Updated internal path references in
cd_worktree.sh."
```

---

### Task 2: Create shell-integration.zsh

**Files:**
- Create: `worktree/shell-integration.zsh`

- [ ] **Step 1: Create the file**

Write `worktree/shell-integration.zsh` with the following content:

```zsh
#!/usr/bin/env zsh

# Shell integration for worktree scripts.
# Sourced from ~/.zshrc via install.sh.
# Defines: create-tree, cd-tree, del-tree

__WORKTREE_DIR="${0:A:h}"

create-tree() { source "${__WORKTREE_DIR}/create_worktree.sh"; }
cd-tree()     { source "${__WORKTREE_DIR}/cd_worktree.sh"; }
del-tree()    { "${__WORKTREE_DIR}/delete_worktree.sh" "$@"; }
```

- [ ] **Step 2: Verify it parses without errors**

```bash
zsh -n worktree/shell-integration.zsh
```

Expected: no output (clean parse).

- [ ] **Step 3: Commit**

```bash
git add worktree/shell-integration.zsh
git commit -m "feat: add shell-integration.zsh for worktree commands

Defines create-tree, cd-tree, del-tree. Resolves script paths
dynamically via zsh \${0:A:h}."
```

---

### Task 3: Create install.sh

**Files:**
- Create: `worktree/install.sh`

- [ ] **Step 1: Create the file**

Write `worktree/install.sh` with the following content:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZSHRC="${HOME}/.zshrc"
INTEGRATION_FILE="${SCRIPT_DIR}/shell-integration.zsh"
SOURCE_LINE="source \"${INTEGRATION_FILE}\""
MARKER_START="# --- worktree-scripts START ---"
MARKER_END="# --- worktree-scripts END ---"

# --- Validate folder structure ---
required_files=(
  "create_worktree.sh"
  "delete_worktree.sh"
  "cd_worktree.sh"
  "shell-integration.zsh"
)
for f in "${required_files[@]}"; do
  if [[ ! -f "${SCRIPT_DIR}/${f}" ]]; then
    echo "Error: missing required file: ${SCRIPT_DIR}/${f}" >&2
    exit 1
  fi
done

# --- Check prerequisites ---
missing=()
for cmd in gum git zsh; do
  if ! command -v "$cmd" &>/dev/null; then
    missing+=("$cmd")
  fi
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Error: missing required tools: ${missing[*]}" >&2
  echo "Install them before running this script." >&2
  exit 1
fi

# --- Ensure scripts are executable ---
chmod +x "${SCRIPT_DIR}/create_worktree.sh"
chmod +x "${SCRIPT_DIR}/delete_worktree.sh"
chmod +x "${SCRIPT_DIR}/cd_worktree.sh"

# --- Check .zshrc exists ---
if [[ ! -f "$ZSHRC" ]]; then
  echo "Creating ${ZSHRC} (did not exist)."
  touch "$ZSHRC"
fi

# --- Idempotency check ---
if grep -qF "$MARKER_START" "$ZSHRC"; then
  echo "Already installed. To reinstall, remove the worktree-scripts block from ${ZSHRC} and run again."
  exit 0
fi

# --- Append source line ---
{
  echo ""
  echo "$MARKER_START"
  echo "$SOURCE_LINE"
  echo "$MARKER_END"
} >> "$ZSHRC"

echo "Installed successfully."
echo "Run 'source ~/.zshrc' or open a new terminal to activate."
echo ""
echo "Commands available:"
echo "  create-tree   — create a new worktree"
echo "  cd-tree       — cd into a worktree"
echo "  del-tree      — delete worktrees"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x worktree/install.sh
```

- [ ] **Step 3: Verify it parses without errors**

```bash
bash -n worktree/install.sh
```

Expected: no output (clean parse).

- [ ] **Step 4: Commit**

```bash
git add worktree/install.sh
git commit -m "feat: add install.sh for one-command worktree setup

Validates folder structure, checks prerequisites (gum, git, zsh),
ensures .zshrc exists, and appends a source line idempotently."
```

---

### Task 4: Create README.md

**Files:**
- Create: `worktree/README.md`

- [ ] **Step 1: Create the file**

Write `worktree/README.md` with the following content:

```markdown
# Worktree Scripts

Interactive git worktree management powered by [gum](https://github.com/charmbracelet/gum).

## Prerequisites

- **zsh** — your default shell
- **git** — version control
- **gum** — interactive TUI prompts
  - macOS: `brew install gum`
  - Linux: see [gum install docs](https://github.com/charmbracelet/gum#installation)

## Installation

Clone this repo and run the installer:

    git clone https://github.com/RKPinata/shell-scripts.git ~/scripts
    ./scripts/worktree/install.sh

Then activate in your current session:

    source ~/.zshrc

## Commands

### create-tree

Create a new worktree from a new or existing branch. Prompts for branch name,
prefix, base branch, and dev server port. Restores environment files and
optionally runs `npm ci`.

### cd-tree

Switch into an existing worktree. Presents a list of all worktrees
(excluding the current directory) and `cd`s into the selected one.

### del-tree

Select one or more worktrees to force-delete. Warns about uncommitted
changes before proceeding.

## Uninstall

Remove the following block from `~/.zshrc`:

    # --- worktree-scripts START ---
    source "/path/to/worktree/shell-integration.zsh"
    # --- worktree-scripts END ---
```

- [ ] **Step 2: Commit**

```bash
git add worktree/README.md
git commit -m "docs: add README for worktree scripts

Covers prerequisites, installation, command reference, and uninstall."
```

---

### Task 5: End-to-end verification

- [ ] **Step 1: Verify folder structure**

```bash
ls -1 worktree/
```

Expected output:
```
README.md
cd_worktree.sh
create_worktree.sh
delete_worktree.sh
install.sh
shell-integration.zsh
```

- [ ] **Step 2: Run install.sh and verify .zshrc was updated**

```bash
./worktree/install.sh
```

Expected: "Installed successfully." message.

Then verify the block was appended:

```bash
grep -A2 "worktree-scripts START" ~/.zshrc
```

Expected:
```
# --- worktree-scripts START ---
source "/Users/<you>/scripts/worktree/shell-integration.zsh"
# --- worktree-scripts END ---
```

- [ ] **Step 3: Run install.sh again to verify idempotency**

```bash
./worktree/install.sh
```

Expected: "Already installed." message. No duplicate block in `.zshrc`.

- [ ] **Step 4: Source and verify commands exist**

```bash
source ~/.zshrc
which create-tree && which cd-tree && which del-tree
```

Expected: all three resolve as shell functions.

- [ ] **Step 5: Final commit (if any cleanup needed)**

Only if verification reveals issues. Otherwise, no action.
