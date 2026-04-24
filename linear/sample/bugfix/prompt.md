## Context

You are tasked to Investigate this QA-raised bug

- The launcher provides the Linear issue identifier, Linear prompt/context, a base branch hint, and a target branch hint.
- `AI_DECIDE_BASE_BRANCH` means the launcher could not confidently identify the correct base branch. Inspect the repository context and choose the best base branch before continuing.
- `AI_DECIDE_BRANCH_NAME` means the launcher could not confidently identify the correct target branch. Create a sensible branch name that matches the repo's conventions.

## Worktree Preparation

1. Review the provided issue context carefully and summarize the task to yourself before making changes.
2. Resolve the real base branch if the launcher passed `AI_DECIDE_BASE_BRANCH`.
3. Resolve the real target branch if the launcher passed `AI_DECIDE_BRANCH_NAME`.
4. Create a worktree from the resolved base branch.
5. Create or switch to the resolved target branch inside that worktree.

### Branching guidance

- Prefer existing repo naming conventions. Refer to `respond-io/.claude.md`
- If the issue appears to belong to a flight, use the matching `flight/*` branch as the base branch.
- If the launcher's branch hint is already a valid issue branch, prefer it unless the repository context clearly contradicts it.

## Debugging

Invoke skill: superpowers:systematic-debugging to start debugging.

After investigation:

1. If the issue is simple and low-risk:
   - fix the issue
2. If the issue is complex or risky:
   - explain possible fixes with tradeoffs,
   - identify the safest next step.
3. If you are unsure, cannot reproduce confidently, or need runtime evidence:
   - explain what additional information is needed,
   - guide the developer on what to capture next.

Constraints:

- Do not fix complex issues directly.
- Prefer investigation, root cause analysis, and clear next steps.
- Keep the response structured and practical.

Expected output format:

- Issue summary
- Investigation findings
- Root cause
- Fix applied / Possible fixes / Need runtime debugging
- Validation steps
- Next action requested
