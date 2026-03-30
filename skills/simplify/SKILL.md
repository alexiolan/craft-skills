---
name: simplify
description: "Use after implementation is complete to review changed code for reuse opportunities, quality issues, and DDD compliance. Identifies missed shared components, unnecessary complexity, and boundary violations."
---

# Simplify

Review changed code for reuse opportunities, quality, and DDD compliance.

## Input

The user input is: `$ARGUMENTS`

- **File paths or git ref**: Review specific files or changes since a commit
- **Empty**: Review all uncommitted changes (`git diff` + `git diff --staged`)

## Step 1: Identify Changed Code

```bash
# If no specific input, check all changes
git diff --name-only
git diff --staged --name-only
```

Read each changed file to understand what was modified.

## Step 2: Reuse Check

For each changed file, check against the project's shared inventory:

- **Shared components**: Is there an existing component in `src/domain/shared/ui/` that could replace custom UI?
- **Shared hooks**: Is there an existing hook in `src/domain/shared/hooks/` that duplicates new logic?
- **Form fields**: Are raw inputs used instead of existing fields from `src/domain/forms/fields/`?
- **Cross-domain patterns**: Is the same utility being created in multiple domains? Should it be in shared?

## Step 3: DDD Boundary Check

For each changed file in a business domain:
- Are all imports from shared domains or the same domain?
- Are new types/utilities placed in the correct domain?
- Should any new shared functionality be in `src/domain/shared/` instead?

## Step 4: Quality Review

Check for:
- **Unnecessary complexity**: Can this be simplified without losing functionality?
- **Premature abstraction**: Is a helper/utility created for a one-time operation?
- **Missing error handling at boundaries**: User input validation, API response handling
- **Excessive error handling internally**: Trust internal code, don't over-validate
- **Consistent naming**: Do new names follow existing codebase conventions?

## Step 5: Verification

**Iron Law: Evidence before assertions.**

Run the project's verification commands:
1. `npm run lint`
2. `npx tsc --noEmit`
3. `npm run format`
4. `npm run build`

Report actual output, not assumptions about output.

## Step 6: Report

Present findings with specific file:line references:

```
## Review Findings

### Reuse Opportunities
- `src/domain/X/ui/CustomButton.tsx:15` — could use shared `Button` component instead

### DDD Concerns
- `src/domain/rooms/feature/RoomList.tsx:8` — imports from properties domain (boundary violation)

### Quality
- `src/domain/X/utils/formatDate.ts` — single-use utility, inline instead

### Verification
- Lint: PASS
- TypeScript: PASS
- Build: PASS
```
