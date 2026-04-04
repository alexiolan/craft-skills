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

## Step 2: Analyze with Graph + LLM (before reading files)

Use the **graph → LLM → manual** priority to minimize token usage:

**Graph (if code-review-graph available):** First run `build_or_update_graph_tool` (incremental, fast if current). Then:
- `get_impact_radius_tool` on each changed file — shows blast radius and downstream consumers
- `query_graph_tool` with `imports_of` on changed files — reveals DDD boundary violations instantly
- `query_graph_tool` with `importers_of` on changed files — shows what depends on the changed code
- **Do NOT use `get_architecture_overview_tool` or `list_communities_tool`** — both can overflow context (150-300K chars)

**LLM agent (if available, run in background):**
```
bash <craft-scripts>/llm-agent.sh "Review these changed files for: 1) Reuse opportunities vs src/domain/shared/ 2) DDD boundary violations (cross-domain imports) 3) Unnecessary complexity. Files: [list from git diff]" <project-root>
```

> **Path resolution:** `<craft-scripts>` is the craft-skills scripts directory from bootstrap context. If not in context: `find ~/.claude/plugins -name "llm-agent.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1`

**Then read only** the files the graph or LLM flagged as having issues — don't read every changed file upfront.

## Step 3: Reuse Check

For each changed file, check against the project's shared inventory:

- **Shared components**: Is there an existing component in `src/domain/shared/ui/` that could replace custom UI?
- **Shared hooks**: Is there an existing hook in `src/domain/shared/hooks/` that duplicates new logic?
- **Form fields**: Are raw inputs used instead of existing fields from `src/domain/forms/fields/`?
- **Cross-domain patterns**: Is the same utility being created in multiple domains? Should it be in shared?

## Step 4: DDD Boundary Check

For each changed file in a business domain:
- Are all imports from shared domains or the same domain? (Graph's `imports_of` results show this instantly)
- Are new types/utilities placed in the correct domain?
- Should any new shared functionality be in `src/domain/shared/` instead?

## Step 5: Quality Review

Check for:
- **Unnecessary complexity**: Can this be simplified without losing functionality?
- **Premature abstraction**: Is a helper/utility created for a one-time operation?
- **Missing error handling at boundaries**: User input validation, API response handling
- **Excessive error handling internally**: Trust internal code, don't over-validate
- **Consistent naming**: Do new names follow existing codebase conventions?

## Step 6: Verification

**Iron Law: Evidence before assertions.**

Run the project's verification commands:
1. `npm run lint`
2. `npx tsc --noEmit`
3. `npm run format`
4. `npm run build`

Report actual output, not assumptions about output.

## Step 7: Report

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
