---
name: simplify
description: "Use after implementation is complete to review changed code for reuse opportunities, quality issues, and architecture compliance. Identifies missed shared components, unnecessary complexity, and boundary violations."
---

# Simplify

Review changed code for reuse opportunities, quality, and architecture compliance.

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

Use the **graph → LLM → manual** priority. Claude should NOT read changed files directly — let LLM do the reading.

**Graph (if code-review-graph available):** Run `build_or_update_graph_tool`, then:
- `get_impact_radius_tool` on each changed file — shows blast radius and downstream consumers
- `query_graph_tool` with `imports_of` on changed files — reveals architecture boundary violations instantly
- `query_graph_tool` with `importers_of` on changed files — shows what depends on the changed code
- **Do NOT use `get_architecture_overview_tool`, `list_communities_tool`, or `detect_changes_tool`** — all three can overflow context (90-300K chars)

**LLM (MANDATORY) — Check LM Studio first (Bash tool, wait for result):**
```bash
CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "llm-agent.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1) && curl -s --max-time 2 ${LLM_URL:-http://127.0.0.1:1234} > /dev/null 2>&1 && echo "LLM_AVAILABLE:$CRAFT_SCRIPTS" || echo "LLM_UNAVAILABLE"
```

If `LLM_AVAILABLE`, run with Bash tool (`run_in_background: true`, timeout 300000ms):
```bash
bash "$CRAFT_SCRIPTS/llm-agent.sh" "Review these changed files for: 1) Reuse opportunities — check if the project's shared modules already have equivalent utilities 2) Architecture boundary violations (cross-module imports between business modules) 3) Unnecessary complexity or premature abstractions 4) Naming consistency. Changed files: [list from git diff]. Also check these related files flagged by graph: [high-risk files from get_impact_radius_tool]" <project-root>
```

Then unload: `bash "$CRAFT_SCRIPTS/llm-unload.sh"`. If `LLM_UNAVAILABLE`, fall back to reading files graph flagged as high-risk. Filter out false positives about plugins/skills.

**Wait for LLM results before proceeding to Steps 3-5.** The LLM handles the file reading — Claude's role in Steps 3-5 is to triage and verify LLM findings using graph data, not to re-read every file.

If LLM is unavailable, fall back to reading only the files graph flagged as high-risk.

## Step 3: Reuse Check

Triage LLM findings (if available) and graph results for reuse opportunities:

- **Shared components**: Is there an existing shared component that could replace custom code?
- **Shared hooks/utilities**: Is there an existing utility that duplicates new logic?
- **Form fields**: Are raw inputs used instead of existing form components (if applicable)?
- **Cross-module patterns**: Is the same utility being created in multiple modules? Should it be shared?

Only read a specific file if the LLM flagged an issue you need to verify.

## Step 4: Architecture Boundary Check

Use graph `imports_of` results and LLM findings:
- Are all imports from shared modules or the same module?
- Are new types/utilities placed in the correct module?
- Should any new shared functionality be in the project's shared module instead?

## Step 5: Quality Review

Based on LLM findings, check for:
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

### Architecture Concerns
- `src/modules/rooms/RoomList.tsx:8` — imports from another business module (boundary violation)

### Quality
- `src/domain/X/utils/formatDate.ts` — single-use utility, inline instead

### Verification
- Lint: PASS
- TypeScript: PASS
- Build: PASS
```
