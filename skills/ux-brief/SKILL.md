---
name: ux-brief
description: "Generate a structured UX brief for a feature before implementation — diagnosis + prioritized patches + success criteria — that downstream implementer agents (Sonnet, Gemma, Haiku) execute without clarification. Invoked by architect/craft when the spec contains UI components. Solo frontend-design by default; combined mode (frontend-design + ui-ux-pro-max) for complex UI based on spec complexity tag."
---

# UX Brief

Produce a per-feature `ux-brief.md` that translates a spec into concrete, implementable UX patches for downstream agents. The brief is the **design contract** that develop/implement agents read alongside the plan.

## When to invoke

Architect / craft call this skill when:
- The feature involves new or modified UI (components, pages, forms, tables, modals)
- A spec file exists at `.claude/plans/specs/` or `.claude/plans/`
- `.claude/aesthetic-direction.md` exists (if not, invoke `aesthetic-direction` first)

Skip for backend-only changes, configuration changes, or pure refactors with no UI surface area.

## Input

- `$ARGUMENTS`: path to the spec file (or the feature plan file if no separate spec exists)
- Reads: `.claude/aesthetic-direction.md`, project CLAUDE.md, target UI files

## Process

### Step 1: Complexity gate (hybrid inference + override)

Determine whether this feature needs **solo** frontend-design or **combined** (frontend-design + ui-ux-pro-max).

**1a — Explicit override (authoritative):** Parse the spec's YAML frontmatter. If `complexity:` is present with tags, use those:

```yaml
---
title: ...
complexity: [comparison, data-dense]
---
```

Recognized complexity tags: `comparison`, `dashboard`, `complex-form`, `data-dense`, `multi-step`, `table-heavy`.

**1b — Inference (fallback):** If no explicit tag, scan the spec text for keywords:

| Keyword in spec | Implied complexity |
|---|---|
| "compare", "comparison", "side-by-side" | `comparison` |
| "dashboard", "metrics", "KPI", "analytics" | `dashboard` |
| "multi-step form", "wizard", "checkout" | `complex-form`, `multi-step` |
| "table", "grid of N columns", "data-dense" | `data-dense`, `table-heavy` |
| Small/simple form (1-3 fields), button, toggle, single modal | (no tag — solo) |

If inference is **borderline**, pick solo and note in the brief: `> Predicted complexity: {reasoning}. Add complexity: [...] to the spec frontmatter to override.`

**1c — Decision:**
- Any complexity tag matches → **combined mode**
- No tags / none match → **solo mode**

### Step 2: Check skill availability

```bash
FD=$(find ~/.claude/plugins -type d -name "frontend-design" 2>/dev/null | head -1)
PM=$(find ~/.claude/plugins -type d -name "ui-ux-pro-max" 2>/dev/null | head -1)

[ -n "$FD" ] && echo "FD_AVAILABLE" || echo "FD_UNAVAILABLE"
[ -n "$PM" ] && echo "PM_AVAILABLE" || echo "PM_UNAVAILABLE"
```

Gate:
- `FD_UNAVAILABLE` → Abort this skill. Log: "frontend-design skill is required for UX brief generation. Install it or run the feature without design-layer gating." Architect continues without a brief.
- Solo mode OR `PM_UNAVAILABLE` in combined mode → run solo (Step 3a)
- Combined mode AND both available → run combined (Step 3b)

### Step 3a: Solo mode

Dispatch an agent (**general-purpose** type, opus model) with this instruction:

```
You are producing a UX brief for downstream implementation agents.

Mandatory first step: invoke the frontend-design:frontend-design skill via the Skill tool. Do NOT invoke ui-ux-pro-max; this run is isolated.

Read, in this order:
1. .claude/aesthetic-direction.md — the project's design contract (HARD constraint)
2. Project CLAUDE.md (parent + project-level)
3. The spec: {spec-path}
4. The target UI files mentioned in the spec + any existing implementation being replaced

Produce .claude/plans/YYYY-MM-DD-{feature}/ux-brief.md with this structure:

# {Feature} — UX Brief

## Aesthetic anchor
Reference .claude/aesthetic-direction.md. 1-2 sentences on how this feature fits.

## UX jobs-to-be-done (ranked)
1. Primary: ...
2. Secondary: ...
3. Tertiary: ...

## Diagnosis (P0/P1/P2)
### P0 · <problem>
- Where: file:line
- Symptom: ...
- Root cause: UX principle violated

### (repeat for each)

## Patches (same priority order)
### Patch for "<problem>"
- Pattern: named UX pattern
- Why this over alternatives: principled 1-2 sentence justification (cite UX principle — JTBD, progressive disclosure, Fitts, Hick, pre-attentive, negativity bias, F-pattern, spatial co-location, color-contrast)
- Touch: exact file paths + component names
- Tokens to use: specific project Tailwind/DaisyUI/CSS-variable primitives from aesthetic-direction + observed in code
- Interaction spec: hover/focus/click/keyboard (1-3 bullets)
- Mobile behavior: explicit strategy
- A11y notes: contrast / ARIA / keyboard
- **Layout-parity guard** (MANDATORY if patch adds conditional chrome to a shared component): specify min-height, placeholder slot, or unconditional container so winner-vs-non-winner items do not desync.
- Effort: S / M / L

## Out of scope
3-5 items with 1-line reason each

## Success criteria
Testable checklist (≤7 items). Downstream agent knows they are done when these pass.

## Quality bar
- Actionability: a Sonnet or Haiku agent must implement any patch without asking clarifying questions.
- Specificity over taste: exact tokens, exact files, exact conditions.
- Respect the existing architecture: no rewrites, patches fit the current DDD structure.
- UX reasoning cites principles, not feelings.
- Prioritize by leverage: P0 is biggest UX win per unit of effort.

Hard constraints:
- NO HTML mockup files.
- Stay inside the project's existing DaisyUI/Tailwind/CSS-variable vocabulary (read from aesthetic-direction.md).
- NO aesthetic-novelty proposals.
- Do not propose changes outside the feature's stated scope.
- For every patch that adds conditional UI to a shared component, the Layout-parity guard field is non-optional.

Return a 4-sentence summary: (1) top 3 P0 problems, (2) top 3 patches, (3) what frontend-design specifically contributed to reasoning, (4) path to the brief file.
```

### Step 3b: Combined mode

Same as Step 3a with these differences:

1. The agent first invokes `frontend-design:frontend-design` to establish principle lens (voice, hierarchy discipline, attention architecture).
2. Then invokes `ui-ux-pro-max:ui-ux-pro-max` to add pattern catalog (KPI strip, winner-per-metric, progressive-disclosure, error-summary, touch-target-size, color-not-only, direct-labeling) and a11y checklist rule citations.
3. The agent **must** reconcile conflicts: favor frontend-design for voice/principle, pro-max for pattern specificity + a11y citations. Note any conflicts in the brief under a short "Skill reconciliation" section.
4. The brief is written to the same location.

**Extra quality clause in combined mode:** for every patch, the a11y notes section must cite at least one pro-max rule by name when applicable (`color-not-only`, `touch-target-size`, `aria-live`, `error-summary`, etc.).

### Step 4: Return path

Report to the caller:
- Path to `ux-brief.md`
- Mode used (solo / combined)
- Skill availability summary
- Any ambiguity detected in complexity inference (so user can override with explicit frontmatter)

## Output

File: `.claude/plans/YYYY-MM-DD-{feature}/ux-brief.md`

Filename convention: same `YYYY-MM-DD-{feature}` stem as the spec, in a directory (not flat) so the brief lives beside the plan and future design-review.md artifact:

```
.claude/plans/
├── 2026-04-19-compare-products-redesign/
│   ├── spec.md              (moved from .claude/plans/specs/ when directory is created)
│   ├── plan.md              (written by architect)
│   ├── ux-brief.md          (written by ux-brief, THIS skill)
│   └── design-review.md     (written by design-review, later)
```

If the spec is at `.claude/plans/specs/YYYY-MM-DD-{feature}-design.md`, leave it there — don't migrate existing layouts. The new per-feature directory pattern is opt-in and only used for newly created briefs.

## Fallbacks

| Missing | Behavior |
|---|---|
| `frontend-design` skill | Abort skill. Architect logs warning, proceeds with no UX brief. Impl agents lose design-layer context but plan still executes. |
| `ui-ux-pro-max` skill (combined mode requested) | Silent degrade to solo. Brief includes note: `> Pro-max unavailable — consider manual a11y audit of the implemented UI.` |
| No `.claude/aesthetic-direction.md` | Caller (architect/craft) should invoke `aesthetic-direction` skill first. If called without it, skip gracefully and log: "Aesthetic direction missing. Run craft-skills:aesthetic-direction or add UI-design context to CLAUDE.md." |
| Spec file missing | Fail with clear message — this skill requires a written spec. Direct caller to architect/craft. |
