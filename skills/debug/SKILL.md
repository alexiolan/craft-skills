---
name: debug
description: "Use when investigating bugs, errors, failing tests, or unexpected behavior. Enforces systematic root-cause investigation BEFORE attempting any fix. Invoke this skill before writing any fix code."
---

# Debug

Systematic root-cause debugging. No fixes without investigation first.

<HARD-GATE>
Do NOT attempt any fix until you have completed Phase 1 (Root Cause Investigation) and have a clear hypothesis for what is wrong and why. Guessing at fixes wastes time and can introduce new bugs.
</HARD-GATE>

## Phase 1: Root Cause Investigation

Before touching any code:

### 1.1 Read the Error

- Read the FULL error message, stack trace, and any logs
- Don't skim — the answer is often in the details
- Check browser console, terminal output, and build logs

### 1.2 Reproduce Consistently

- Can you trigger the error reliably?
- What are the exact steps?
- Does it happen in all environments or just one?

### 1.3 Check Recent Changes

- `git log --oneline -20` — what changed recently?
- `git diff HEAD~5` — any suspicious changes?
- Did this work before? When did it break?

### 1.4 Gather Evidence at Boundaries

Use the **graph → LLM → manual** priority:

**Step 1 — Graph maps the territory (if code-review-graph available):** First, ensure the graph is fresh — run `build_or_update_graph_tool` (incremental, fast if already current). Then use `get_impact_radius_tool` or `query_graph_tool` with `callers_of`/`callees_of`/`imports_of` on the suspect file. This instantly returns the full dependency chain — all callers, callees, and impacted files — without reading a single file. **Avoid `get_architecture_overview_tool` and `list_communities_tool`** — both can overflow context (150-300K chars). Use targeted queries only.

**Step 2 — Agent reads the code (MANDATORY):** Dispatch a **haiku** agent with `craft-skills:llm-review`.

Task: `explore "Read these files and find where data breaks: [2-3 key files from graph chain]. Report the data flow and any anomalies." <project-root>`

The agent handles the full lifecycle. **Do not read these files yourself** — Claude's role is to interpret the findings.

**Scoping rule:** Always list specific file paths — never ask the agent to "explore" or "search the whole project." Broad prompts cause max-iteration failures.

Graph provides the map (which files matter), agent provides the understanding (what the code does). Together they handle complex multi-service traces that neither could do alone — graph prevents agent from wandering, agent provides code-level insight that graph can't. **Claude's role is to interpret the findings, not to read the files.**

**Fallback — if graph unavailable:** Use Grep to trace imports/exports of the suspect file manually, then pass those files to the LLM agent.
**Fallback — if LLM unavailable:** Use graph results to identify the key 2-3 files, then read them directly.
**Fallback — if both unavailable:** Manual trace with Grep + Read.

Also check directly:
- Check API request/response (network tab, service layer logs)
- Check component props (are they what you expect?)
- Check state (React Query cache, form state)
- Check domain boundaries (are imports correct?)

### 1.5 Trace the Data Flow

Follow the data from source to symptom:
```
API Response → Service Layer → React Query Cache → Component Props → Rendered UI
```

Where in this chain does the data go wrong?

## Phase 2: Pattern Analysis

Is this a known pattern?

| Pattern | Check |
|---|---|
| DDD boundary violation | Import from another business domain? |
| Query cache stale | Missing `invalidateKeys` in mutation? |
| Form validation gap | Schema doesn't match form fields? |
| Type mismatch | API model differs from frontend type? |
| Server/Client component confusion | Using hooks in Server Component? |
| Missing loading state | Data undefined during fetch? |
| Toast not showing | Missing `successMessage` in mutation config? |

## Phase 3: Hypothesis & Testing

1. **State your hypothesis clearly**: "The bug occurs because X, which causes Y"
2. **Design a test**: How can you verify this hypothesis?
3. **Test it**: Add a console.log, check a value, reproduce with specific inputs
4. **Confirm or reject**: Does the evidence support your hypothesis?

If rejected, return to Phase 1 with new information.

## Phase 4: Implementation

Only now do you write the fix:

1. **Fix the root cause**, not the symptom
2. **Verify the fix**: Run the reproduction steps — is the bug gone?
3. **Check for regressions**: Run lint, tsc, build
4. **Verify related functionality**: Did the fix break anything nearby?

### Escalation Rule

After 3+ failed fix attempts:
- **STOP** trying more fixes
- **Question the architecture**: Is the component/hook/pattern fundamentally wrong?
- **Consider a redesign**: Sometimes the fix is a larger refactor
- **Ask the user**: Present what you've tried, what you've learned, and propose alternatives

## Anti-Patterns

Do NOT:
- Apply a fix before understanding the root cause
- Assume the first error you see is the root cause (it may be a symptom)
- Add defensive code (try/catch, null checks) to hide the real problem
- Change multiple things at once — isolate variables
- Keep trying variations of the same approach
