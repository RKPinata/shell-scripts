# Worktree Scripts

Interactive git worktree management powered by [gum](https://github.com/charmbracelet/gum).

Create, switch between, and delete git worktrees with guided prompts — no flags or arguments to remember.

## Installation

Clone the repo

```sh
git clone https://github.com/RKPinata/shell-scripts.git
```

Run the installer

```sh
cd shell-scripts
./worktree/install.sh
```

<details>
<summary>What does the installer do?</summary>

1. Check for required tools (`git`, `gum`, `zsh`) and offer to install any that are missing via Homebrew.
2. Make the worktree scripts executable.
3. Add a source line to your `~/.zshrc` that registers the commands.

</details>

After installation, activate the commands in your current terminal:

```sh
source ~/.zshrc
```

## Commands

| Command       | Description                                         |
| ------------- | --------------------------------------------------- |
| `create-tree` | Create a new worktree from a new or existing branch |
| `cd-tree`     | Switch your terminal into another worktree          |
| `del-tree`    | Select and force-delete one or more worktrees       |

### 1. create-tree — Create a worktree

Run `create-tree` from inside any git repository. It walks you through the full setup interactively.

**Step 1 — Choose mode:**
You are prompted to pick **"new branch"** or **"existing branch"**.

**Step 2a — New branch:**

- Enter a branch name (e.g. `my-feature`).
- Pick a prefix (`feature`, `bugfix`, `hotfix`, `flight`, etc.). The final branch will be `prefix/branch-name`.
- Select a base branch to branch from. `flight/` and `hotfix/` prefixes automatically use `master` as the base.

**Step 2b — Existing branch:**

- Pick from a list of local branches sorted by most recent activity.

**Step 3 — Confirm and create:**
A summary of the worktree path and branch is shown. Confirm to create.

The new worktree is placed at `<repo-root>/.worktrees/<branch-name>`, and your terminal is moved into it.

> **Repo-specific behaviour:** For the `respond-io-web` repository, `create-tree` also restores environment files (`.env`, `.env.local`, etc.) from the main checkout — by symlink by default, or by copy if you set `RESTORE_MODE=copy`. It then offers to run `npm ci` and start a dev server on a chosen port.

### 2. cd-tree — Switch to a worktree

Run `cd-tree` from inside any git repository.

A filterable list of all worktrees (excluding your current directory) is shown. The main checkout is labelled `(main tree)`. Select one and your terminal moves into it.

### 3. del-tree — Delete worktrees

Run `del-tree` from inside any git repository.

A multi-select list of all worktrees (excluding the main checkout) is shown. Press **Space** or **x** to select one or more, then **Enter** to proceed.

You will see:

- A list of what will be deleted.
- A warning that uncommitted changes in those worktrees will be permanently lost.
- A confirmation prompt.

If you are currently inside a worktree that is being deleted, you are automatically moved to the main checkout first.

## Troubleshooting

### 1. create-tree: command not found after installation

The installer adds a source line to `~/.zshrc`, but your current terminal session does not pick it up automatically. Run the following in the the terminal where you are using the command:

```sh
source ~/.zshrc
```

### 2. Not inside a Git repository

All three commands must be run from within a git repository. `cd` into a repo first.

### 3. gum is not installed

If you skipped the automatic install during setup, install gum manually:

```sh
brew install gum
```

### Installer says "Already installed"

The installer is idempotent. If you see this message, the source line is already in your `~/.zshrc`. To reinstall, remove the block between `# --- worktree-scripts START ---` and `# --- worktree-scripts END ---` from `~/.zshrc`, then run the installer again.

## Uninstall

```sh
./worktree/uninstall.sh
```

This removes the shell integration block from `~/.zshrc` and optionally uninstalls `gum` via brew. Then restart your terminal or run `source ~/.zshrc`.
