# Spec: `gum_create_worktree.sh`

## Purpose

An interactive shell script that creates a Git worktree for either a new or existing branch, then restores local-only files (env files, certs, design tokens) into the worktree via symlink or copy. Optionally bootstraps the project by running `npm ci`.

---

## Prerequisites

| Requirement | Check | Failure |
|---|---|---|
| `gum` CLI installed | `command -v gum` | Exit 1 |
| Inside a Git repository | `git rev-parse --is-inside-work-tree` | Exit 1 |
| Main worktree root resolvable | `git worktree list --porcelain` | Exit 1 |

---

## Environment Variables

| Variable | Default | Effect |
|---|---|---|
| `RESTORE_MODE` | `symlink` | Set to `copy` to copy files into the worktree rather than symlink them |

---

## Derived Variables

| Variable | Source |
|---|---|
| `MAIN_ROOT` | First entry from `git worktree list --porcelain` — correct even when invoked from inside a worktree |
| `WORKTREE_PARENT` | `"${MAIN_ROOT}/.worktrees"` — subdirectory created inside the main checkout root |

---

## Helper Functions

### `restore_item <rel-path>`

Restores a single file or directory from `MAIN_ROOT` into the new worktree at `abs_path`.

```mermaid
flowchart TD
    A[restore_item rel_path] --> B{source exists at MAIN_ROOT?}
    B -- No --> Z[return 0: skip silently]
    B -- Yes --> C{target is already the correct symlink?}
    C -- Yes --> Z
    C -- No --> D{target exists as something else?}
    D -- Yes --> W[warn: target exists, skipping]
    W --> Z2[return 0]
    D -- No --> E[mkdir -p parent of target]
    E --> F{RESTORE_MODE = copy?}
    F -- Yes --> G[cp -r source → target\nprint copied]
    F -- No --> H[ln -s source → target\nprint linked]
```

### `restore_glob <pattern>`

Expands a shell glob under `MAIN_ROOT` and calls `restore_item` for each match. Skips non-existent matches silently.

---

## Main Flow

### Top-Level

```mermaid
flowchart TD
    Start([Start]) --> G1{gum installed?}
    G1 -- No --> E1[❌ Exit 1]
    G1 -- Yes --> G2{Inside Git repo?}
    G2 -- No --> E2[❌ Exit 1]
    G2 -- Yes --> D1[Derive MAIN_ROOT via git worktree list]
    D1 --> G3{MAIN_ROOT resolved?}
    G3 -- No --> E3[❌ Exit 1]
    G3 -- Yes --> D2[WORKTREE_PARENT = MAIN_ROOT/.worktrees\nmkdir -p]
    D2 --> M1[gum filter: new branch / existing branch]
    M1 -- cancelled --> E4[Exit 1]
    M1 -- new branch --> NB[New Branch Flow]
    M1 -- existing branch --> EB[Existing Branch Flow]
    NB --> WT[Worktree created at abs_path]
    EB --> WT
    WT --> G4{abs_path directory exists?}
    G4 -- No --> E5[❌ Exit 1: creation failed]
    G4 -- Yes --> R[Restore local files]
    R --> NI{gum confirm: Run npm ci in app/?}
    NI -- Yes --> NI2[npm ci in abs_path/app]
    NI -- No --> OUT[Print: cd abs_path/app && npm run dev-direct]
    NI2 --> OUT
```

---

### New Branch Flow

```mermaid
flowchart TD
    A([New Branch]) --> B[gum input: enter branch name]
    B -- cancelled/empty --> Z[Exit 1]
    B -- entered --> C[gum filter: select prefix\nflight · hotfix · feature · bugfix\nimprovement · resolve · other · test]
    C -- cancelled --> Z
    C -- selected --> D[full_branch = prefix/branch_name]
    D --> E[abs_path = WORKTREE_PARENT/branch_name]
    E --> F{abs_path already exists?}
    F -- Yes --> E2[❌ Exit 1: path collision]
    F -- No --> S[Show: worktree path & branch]
    S --> CN{gum confirm: Create worktree?}
    CN -- No --> Z
    CN -- Yes --> WT[git worktree add -b full_branch abs_path]
    WT --> Done([→ Top-level continues])
```

---

### Existing Branch Flow

```mermaid
flowchart TD
    A([Existing Branch]) --> B[git for-each-ref: list branches\nsorted by committerdate desc]
    B --> G1{Any branches found?}
    G1 -- No --> E1[❌ Exit 1]
    G1 -- Yes --> C[gum filter: select branch]
    C -- cancelled --> Z[Exit 1]
    C -- selected --> D[Flatten: replace / with _ in branch name]
    D --> E[abs_path = WORKTREE_PARENT/flattened]
    E --> F{abs_path already exists?}
    F -- Yes --> E2[❌ Exit 1: path collision]
    F -- No --> G2{Branch checked out in another worktree?}
    G2 -- Yes --> E3[❌ Exit 1: already checked out]
    G2 -- No --> S[Show: worktree path & branch]
    S --> CN{gum confirm: Create worktree?}
    CN -- No --> Z
    CN -- Yes --> WT[git worktree add abs_path selected_branch]
    WT --> Done([→ Top-level continues])
```

---

## File Restoration

After worktree creation the following are restored from `MAIN_ROOT`:

| Item | Method |
|---|---|
| `.env` | `restore_item` |
| `.env.local` | `restore_item` |
| `.env.*.local` | `restore_glob` |
| `.env.direct` | `restore_item` |
| `.env.staging` | `restore_item` |
| `.env.production` | `restore_item` |
| `app/.env` | `restore_item` |
| `app/.env.direct` | `restore_item` |
| `dev/certs` | `restore_item` |
| `app/public/design-tokens.source.json` | `restore_item` |

Each item is symlinked by default. Set `RESTORE_MODE=copy` to copy instead.

---

## Guards & Error Handling

| Condition | Message | Exit |
|---|---|---|
| `gum` not installed | `❌ gum is not installed. Exiting.` | 1 |
| Not in a Git repo | `❌ Not inside a Git repository. Exiting.` | 1 |
| MAIN_ROOT unresolvable | `❌ Could not derive main checkout root. Exiting.` | 1 |
| Mode selection cancelled | _(gum cancellation)_ | 1 |
| `abs_path` already exists | `❌ Directory $abs_path already exists. Exiting.` | 1 |
| Branch already checked out | `❌ Branch $branch is already checked out in another worktree. Exiting.` | 1 |
| Worktree dir absent post-create | `❌ Worktree creation failed; skipping restore.` | 1 |
| Ctrl+C at any point | `🚪 Exiting...` | 1 |
| `restore_item` target collision | `[warned] $rel_path — target exists, skipping` | _(continues)_ |
| `npm ci` fails | `⚠️ npm ci exited with an error` | _(continues)_ |

---

## Worktree Path Conventions

| Mode | Path | Branch |
|---|---|---|
| New | `WORKTREE_PARENT/<branch_name>` | `<prefix>/<branch_name>` |
| Existing | `WORKTREE_PARENT/<branch_name_with_/_replaced_by_>` | `<selected_branch>` |

`WORKTREE_PARENT` is `<MAIN_ROOT>/.worktrees`, created automatically. All worktrees are placed inside the main checkout root rather than alongside it.

---

## Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success (or user-cancelled npm ci — script still exits 0) |
| `1` | Guard failure, user cancellation, or creation error |
