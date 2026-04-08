# gum_create_worktree.sh

Interactive worktree creation script using [gum](https://github.com/charmbracelet/gum) for guided prompts.

## Purpose

Creates a git worktree under `<repo-root>/.worktrees/`, assigns a dev server port, restores local-only files (env files, certs, design tokens), and optionally bootstraps with `npm ci`.

## Prerequisites

- **gum** — `brew install gum`
- Must be run from inside a git repository

## Usage

```bash
source gum_create_worktree.sh
```

> The script uses `return` for clean exits, so it should be **sourced** rather than executed as a subprocess. If you alias it (e.g. `alias gmtree='source /path/to/gum_create_worktree.sh'`), sourcing happens automatically.

## Workflow

1. **Mode selection** — choose "new branch" or "existing branch"
2. **Branch setup**
   - *New branch:* enter a name, pick a prefix (`flight`, `hotfix`, `feature`, `bugfix`, `improvement`, `resolve`, `test`, `other`), and select a base branch. `flight`/`hotfix` branches always base off `master`; all others let you pick (with `flight/*` branches listed first).
   - *Existing branch:* select from local branches sorted by recent activity.
3. **Port assignment** — suggests the lowest available port starting at `8080`, skipping any port already claimed by another worktree's `.dev-port` file. You can override the suggestion.
4. **Confirmation** — review the worktree path, branch, source, and port before proceeding.
5. **Worktree creation** — runs `git worktree add`.
6. **File restoration** — symlinks (or copies) local-only files from the main checkout into the new worktree (see below).
7. **Bootstrap** — optionally runs `npm ci` inside `app/`.
8. **Dev server** — writes a `dev.sh` launcher into the worktree root and starts the dev server on the chosen port.

## Restored Files

The following are symlinked from the main checkout into the new worktree:

| Path | Description |
|---|---|
| `.env`, `.env.local`, `.env.*.local` | Root environment files |
| `.env.direct`, `.env.staging`, `.env.production` | Deployment-specific env files |
| `app/.env`, `app/.env.direct` | App-level environment files |
| `dev/certs` | Local development certificates |
| `app/public/design-tokens.source.json` | Design tokens |

Missing files are silently skipped. Existing targets are not overwritten.

### Copy mode

By default, files are **symlinked**. Set `RESTORE_MODE=copy` before running the script to **copy** them instead:

```bash
RESTORE_MODE=copy source gum_create_worktree.sh
```

## Generated Files

| File | Purpose |
|---|---|
| `.dev-port` | Stores the assigned port number. Used by port allocation and `dev.sh`. |
| `dev.sh` | Launches `npm run dev-direct -- --port <port>` from the worktree's `app/` directory. |

## Safety Guards

- Exits if `gum` is not installed
- Exits if not inside a git repository
- Exits if the main checkout root cannot be determined
- Exits if the target worktree directory already exists
- Exits if the selected branch is already checked out in another worktree
- Validates port is between 1024 and 65535
- Skips file restoration if worktree creation fails
- Ctrl+C exits cleanly at any point
