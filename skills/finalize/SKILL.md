---
name: finalize
description: "Use when an approved implementation plan already exists (from craft, implement, or architect) and needs to be executed and tested. Combines develop + browser-test into a single pipeline."
---

# Finalize

Execute an already-approved plan and test the result. Use after planning has already produced a plan file.

**Pipeline:** Develop → Browser Test → Report

## Input

The user input is: `$ARGUMENTS`

- **Plan path**: Path to the implementation plan to execute
- **Empty**: Auto-detect the most recent plan from `.claude/plans/` (excluding `archive/` and `specs/`)

If no plan is found, suggest running `craft-skills:architect` or `craft-skills:craft` first.

## Phase 1: Develop

Invoke `craft-skills:develop` with the plan.

## Phase 2: Browser Test

After a successful build, invoke `craft-skills:browser-test`.

If the dev server isn't running, start it with `npm run dev` in the background before testing.

## Phase 3: Report

Summarize:
- Files created/modified
- Key implementation decisions
- Test results (pass/fail per scenario)
- Any issues or notes

## Important

- If Phase 1 fails to build after reasonable attempts, stop and report before starting Phase 2
- Do not exit prematurely — follow both phases thoroughly
