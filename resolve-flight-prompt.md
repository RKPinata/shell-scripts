## Task

Resolve the merge of master into the resolve branch named above. The merge is in progress in the worktree named above. Git has not committed it.

The developer decides anything that git history and the code cannot settle. You decide the rest.

The developer notes above come from the developer. Where they conflict with this file, follow the notes.

## Git rules

- Stay on the resolve branch. Do not check out, stash, reset, rebase or abort the merge.
- Do not commit or push. The finish command does both after the developer approves.
- Stage each resolved file by path with `git add <path>`. Never run `git add -A`, `git add .` or `git commit -a`.
- Leave the untracked files listed above alone.

## Resolving

For each conflicted file:

1. Read both sides. `git log --merge -p -- <path>` shows the commits on each side that touched it.
2. Find why each side changed. Read the commit messages, and the PR with `gh pr list --search <sha> --state merged`.
3. Pick a resolution.

Use a skill where one fits:

- `pnpm-lock.yaml` or `package.json`: `respond-io-frontend:resolving-package-conflicts`. Never run a bare `pnpm install` to fix the lockfile.
- Locale JSON files: compare key sets across base, ours and theirs. A hunk can duplicate a moved block of keys.

### `@respond-io/ui` version conflicts

`@respond-io/ui` is the DLS package. A flight branch often pins a dev build named `<release>-dev.g<sha>`. The `<sha>` is a commit on the `respond-io/ui` branch with the same name as the flight branch. Each push to that ui branch publishes a new build and opens a pin PR against the flight branch. Master pins a published release. Each version can lack something the other side's code imports.

1. Find what each side needs. `gh api repos/respond-io/ui/compare/v<master release>...<flight sha>` lists the ui commits that only the flight's build has. The reverse compare lists the commits that only the release has. Grep `src` for the components and icons those commits add.
2. Look for a newer dev build. Run `npm view @respond-io/ui time --json` from the scratchpad, because conflict markers in `package.json` make pnpm fail. Also run `gh pr list --base <flight branch> --state open --search 'pin @respond-io/ui in:title'`.
3. Pin a dev build when compare shows it 0 commits behind both master's release tag and the flight's current pin. Use `pnpm add --save-exact @respond-io/ui@<version>`. Tell the developer that the open pin PR for that build is now redundant.
4. If no build is 0 behind both, stop and ask. Show what each version lacks and which files break without it.

Resolve it yourself when history or the code shows the answer. Examples:

- One side renamed or moved code and the other side edited it. Apply the edit at the new place.
- Both sides added different entries to the same list or import block. Keep both.
- One side's change was reverted, or superseded by a later commit.

Record the reason for each of these choices. The summary needs it.

Stop and ask the developer when the intent is unclear. Examples:

- Both sides changed the same behaviour in different ways.
- One side deleted a file that the other side changed, and history does not say why.
- The resolution is a product decision.

When you ask, show both sides, give the options, and say which one you recommend.

After the conflicts, check the files git merged cleanly for breaks it cannot see:

- imports of files that master moved or deleted
- duplicate locale keys
- calls to functions whose signature changed on one side

Run `pnpm exec eslint` on the resolved `.js`, `.ts` and `.vue` files. Run the unit tests for the code you touched.

## Summary

When every conflict is staged, write a summary:

- **Resolved files**: for each file, what conflicted, the resolution, and the evidence (commit, PR or code).
- **Judgement calls**: each choice that history did not settle outright, and why you made it.
- **Other changes**: anything you changed outside the conflict hunks.
- **Checks**: the lint and test commands you ran and their results.

Then wait for the developer to reply "ok".

## Finishing

After "ok", run the finish command with a 600000 ms timeout. The pre-commit hook runs the full unit test suite.

- It commits the merge, pushes the branch, opens the draft PR and switches the worktree back to the branch it was on.
- Report the PR URL it prints.
- If it fails, show the error and ask the developer what to do. Add `--no-verify` only if the developer asks for it.
