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
