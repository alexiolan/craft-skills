---
name: develop
description: "Use when an approved implementation plan exists and is ready to be executed. Initializes shared state, dispatches parallel frontend-developer agents, performs integration review, and runs full verification (lint, tsc, format, build)."
---

# Develop

Execute an approved implementation plan using parallel frontend-developer agents.

## Input

The user input is: `$ARGUMENTS`

- **Plan path** (e.g., `.claude/plans/2026-03-16-pricing-detail-modal.md`): Use this plan
- **Empty**: Auto-detect the most recent `.md` file in `.claude/plans/` (excluding `archive/` and `specs/`)

If no plan is found, tell the user to run `craft-skills:architect` or `craft-skills:craft` first.

## Step 1: Initialize Shared State

Create a fresh `.shared-state.md` at the project root (delete if one exists from a previous run):

```markdown
# Shared Agent State

> Auto-generated during implementation. Do not edit manually.
> This file is deleted after a successful build.

## Architecture Decisions

<!-- Key decisions carried over from the plan -->

## Created / Modified Files

<!-- Format: - path/to/file.ts (exports: Name1, Name2) -->

## Shared Types & Interfaces

<!-- Format: - InterfaceName — path/to/types.ts — brief description -->

## Dependencies Added

<!-- Format: - package-name (reason for adding) -->

## Notes & Warnings

<!-- Anything other agents should be aware of -->
```

Populate **Architecture Decisions** with key decisions from the plan before dispatching any tasks.

## Step 2: Dispatch Tasks

Read the plan and split it into tasks. Identify which tasks can run in parallel (no dependencies) and which must be sequential.

Dispatch tasks to **frontend-developer** agents. Read the agent prompt template from the `implementer-prompt.md` file in this skill's directory and provide it as context to each agent along with their specific task.

Each agent **MUST**:
1. **Read** `.shared-state.md` before starting work
2. **Read** the full plan for their task's context
3. **Read** the project's CLAUDE.md for conventions
4. **Append** their outputs (created files, exported types, dependencies) to shared state after completing
5. **Check** if another agent has already created something they need — import and reuse
6. **Flag** any conflicts or ambiguities in **Notes & Warnings**

**Parallelization rules:**
- Tasks that create independent files with no imports between them → parallel
- Tasks that depend on types/exports from earlier tasks → sequential
- Data layer tasks (types, service, queries) typically run first
- UI component tasks often run in parallel after data layer is done
- Integration tasks (wiring components together) run last

**Two-stage quality approach:**
After each agent completes, do a quick spec compliance check:
- Did the agent follow the plan?
- Are exports consistent with shared state?
- Any warnings or concerns?

If issues found, dispatch a targeted fix agent before proceeding.

## Step 3: Integration Review

After all agents complete, review `.shared-state.md` holistically:

- Duplicate exports or conflicting type definitions
- Cross-references between agent outputs are consistent
- Naming, patterns, and conventions are consistent
- **Notes & Warnings** section has no unresolved issues

If issues found, dispatch targeted fixes to frontend-developer agents. Repeat until consistent.

## Step 4: Verification

**Iron Law: No completion claims without running these commands AND reading their output.**

Run the full verification sequence:

1. `npm run lint` — fix any errors via agents, repeat until clean
2. `npx tsc --noEmit` — fix any type errors, repeat until clean
3. `npm run format` — format the codebase
4. `npm run build` — fix any build errors, repeat from appropriate step

If a step fails repeatedly (3+ attempts), stop and ask the user for guidance.

## Step 5: Cleanup

After a successful build:

1. Delete `.shared-state.md`
2. Report a summary of all changes made, files created/modified, and any decisions worth noting
