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
| `tree`        | Interactive menu for all worktree commands          |
| `create-tree` | Create a new worktree from a new or existing branch |
| `cd-tree`     | Switch your terminal into another worktree          |
| `del-tree`    | Select and delete one or more worktrees             |

### tree — Interactive menu

Run `tree` from inside any git repository for a filterable menu of all worktree commands.

```
> Create worktree
  Switch to worktree
  Delete worktree
```

Type to filter, press Enter to select. This is a shortcut for the three commands below.

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

> **Repo-specific behaviour:** For the `respond-io-web` repository, `create-tree` hands the new worktree to `bootstrap_worktree.sh`, which restores environment files (`.env`, `.env.direct`, `dev/certs`, `public/design-tokens.source.json`) from the main checkout — by symlink by default, or by copy if you set `RESTORE_MODE=copy` — then runs `pnpm install --frozen-lockfile` at the worktree root. Other repositories get a plain worktree with no bootstrap.
>
> `bootstrap_worktree.sh <worktree-path>` can also be run standalone; it derives the main checkout itself. It is the single source of truth for repo-specific setup, shared with the `creating-worktrees` Claude skill — when the repo layout changes, this is the only file that should need editing.

### 2. cd-tree — Switch to a worktree

Run `cd-tree` from inside any git repository.

A filterable list of all worktrees (excluding your current directory) is shown. The main checkout is labelled `(main tree)`. Select one and your terminal moves into it.

### 3. del-tree — Delete worktrees

Run `del-tree` from inside any git repository.

A multi-select list of all worktrees (excluding the main checkout) is shown. Press **Space** or **x** to select one or more, then **Enter** to proceed.

You will see:

- A list of what will be deleted.
- A note that uncommitted changes travel to the Trash along with the worktree.
- A confirmation prompt.

If you are currently inside a worktree that is being deleted, you are automatically moved to the main checkout first.

Worktrees are moved to the macOS Trash rather than erased, so `del-tree` returns immediately no matter how large `node_modules` is, and a worktree deleted by mistake can be recovered with **Put Back**. The disk space comes back when you empty the Trash. To have macOS do that on its own, turn on *Finder → Settings → Advanced → Remove items from the Trash after 30 days*.

The branch itself is untouched — `del-tree` removes the checkout, not the history.

## Tests

```
./worktree/test_delete_worktree.zsh
```

Each case builds a throwaway repository under a temp root and sources `delete_worktree.sh` against it. `gum` and `trash` are stubbed on `PATH`, so the prompts are scripted and nothing reaches the real Trash.

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
