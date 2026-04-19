---
name: design-review
description: "Post-develop visual regression + design-contract audit. Starts the dev server, captures screenshots of changed UI routes, and dispatches a Haiku-vision agent to compare the result against .claude/aesthetic-direction.md and the feature's ux-brief.md. Flags regressions before browser-test runs. Escalates to Sonnet or Opus only when Haiku flags issues."
---

# Design Review

Automated visual regression and design-contract audit that runs between `develop` (implementation) and `browser-test` (functional testing).

**Why it exists:** paper-grade UX briefs and clean impl-agent output can still produce subtle visual regressions — conditional chrome that desyncs heights, wrapped prices, misaligned grids — that only become visible when the UI renders. This skill catches those with a cheap vision-model pass before the functional test layer runs.

## When to invoke

- `craft-skills:develop` calls this after Step 3.5 (post-develop LLM review) and before Step 4 (verification)
- `craft-skills:craft`, `implement`, `finalize` call this as a phase between Develop and Browser Test
- Can be invoked standalone to audit a specific UI page against the aesthetic direction

Skip when:
- The feature has no UI surface (no `.tsx`/`.vue`/`.svelte` files in `.shared-state.md` changes)
- `.claude/aesthetic-direction.md` does not exist (log: "No aesthetic direction found; skip design-review. Run craft-skills:aesthetic-direction to enable.")
- `@playwright/mcp` MCP server is not available (text-only fallback — see Step 4c)

## Input

- `$ARGUMENTS`:
  - Empty → auto-detect changed UI files from `.shared-state.md` or `git diff --name-only`
  - Route path(s), e.g. `/compare` or `/compare,/clients` → screenshot these specific routes
  - Spec/plan path → extract routes from the plan's "File Structure" section

## Process

### Step 1: Pre-flight checks

```bash
# Verify aesthetic direction exists
if [ ! -f .claude/aesthetic-direction.md ]; then
  echo "AESTHETIC_MISSING"
  exit 0
fi

# Detect changed UI files
if [ -f .shared-state.md ]; then
  CHANGED_UI=$(grep -E '\.(tsx|vue|svelte|jsx)' .shared-state.md | head -20)
else
  CHANGED_UI=$(git diff --name-only HEAD | grep -E '\.(tsx|vue|svelte|jsx)$' | head -20)
fi

if [ -z "$CHANGED_UI" ]; then
  echo "NO_UI_CHANGES"
  exit 0
fi

echo "READY"
echo "$CHANGED_UI"
```

- `AESTHETIC_MISSING` → skip and log message
- `NO_UI_CHANGES` → skip silently
- `READY` → continue

### Step 2: Start dev server

```bash
# Skip if already running on expected port
PORT=${DEV_PORT:-3000}
if lsof -ti:$PORT -sTCP:LISTEN >/dev/null 2>&1; then
  echo "DEV_SERVER_ALREADY_RUNNING on :$PORT"
else
  # Start in background, wait for readiness
  npm run dev > /tmp/craft-dev-$$.log 2>&1 &
  DEV_PID=$!
  for i in {1..30}; do
    sleep 1
    if curl -s http://localhost:$PORT > /dev/null 2>&1; then
      echo "DEV_SERVER_STARTED pid=$DEV_PID port=$PORT"
      break
    fi
  done
  if [ $i -ge 30 ]; then
    echo "DEV_SERVER_FAILED" && exit 1
  fi
fi
```

Record whether the skill started the server (so Step 6 knows whether to stop it).

### Step 3: Identify routes to screenshot

From the changed UI files, map to routes:
- Feature-level components under `src/app/.../page.tsx` → the route path
- UI components → find the parent page by graph query `importers_of` (chain until page.tsx)
- If a `ux-brief.md` exists, use its "Touch" section to identify the features/routes affected

If mapping is unclear, ask the user: "Which routes should I screenshot? (e.g. /compare, /clients)"

### Step 4: Capture screenshots

Load Playwright MCP tools via ToolSearch (`browser_navigate`, `browser_take_screenshot`, `browser_resize`).

For each route:

```
1. Resize browser to 1440x900 (desktop reference)
2. Navigate to http://localhost:${PORT}{route}
3. If login redirect: pause and ask user to log in (use existing session cookies afterwards)
4. Take full-page screenshot: .claude/plans/{feature-dir}/screenshots/{route-slug}-desktop.png
5. Resize to 375x812 (mobile reference)
6. Screenshot again: {route-slug}-mobile.png
7. If ux-brief identifies specific interaction states (hover, expanded, error),
   reproduce each and screenshot as {route-slug}-{state}.png
```

### Step 4c: Text-only fallback

If Playwright MCP is not available:

```bash
# Capture DOM snapshot + computed styles via dev server fetch
curl -s http://localhost:${PORT}{route} > /tmp/dom-snapshot.html
# Note: this is a weaker signal; Haiku can only review markup/class usage, not rendered output
echo "TEXT_FALLBACK: vision regression not possible; review DOM only"
```

The review in Step 5 reads the DOM snapshot and the AESTHETIC_DIRECTION to flag class/token violations, but cannot catch layout/alignment bugs.

### Step 5: Dispatch Haiku vision agent

Dispatch an agent using the Agent tool: **general-purpose**, **haiku** model. Prompt:

```
You are performing a design review. No code changes. Read-only.

Inputs you must read:
1. .claude/aesthetic-direction.md — the project's design contract
2. {ux-brief-path} if it exists (feature-specific success criteria)
3. The screenshots at .claude/plans/{feature-dir}/screenshots/

Compare the rendered UI (screenshots) against:
- The aesthetic direction (color, typography, spacing, density, signature elements)
- The ux-brief's "Success criteria" section (if brief exists)
- General regression heuristics: uniform height of sibling cards, no text wrapping where not intended, consistent alignment, no overlap or clipping, color-not-only encoding, visible focus states (where focus is visible in a screenshot)

Output a structured review file at .claude/plans/{feature-dir}/design-review.md:

# Design Review — {feature}

## Summary
- Status: PASS / MINOR_ISSUES / MAJOR_ISSUES
- Screenshots reviewed: {list}

## Aesthetic compliance
- {PASS/FAIL} Typography: {observation}
- {PASS/FAIL} Color palette: {observation}
- {PASS/FAIL} Density & spacing: {observation}
- {PASS/FAIL} Signature elements: {observation}

## Regression findings
### (list, if any)
- [SEVERITY: critical|major|minor] Description — evidence: {screenshot filename + region} — suggested fix: {1-2 sentences}

## UX-brief success criteria
For each criterion in the brief, mark PASS/FAIL with evidence from the screenshot.

## Recommended next action
- PASS → proceed to browser-test
- MINOR_ISSUES → fix via develop agent (small, specific patches listed above); re-run design-review
- MAJOR_ISSUES → escalate to Sonnet/Opus design-review; may require ux-brief revision

End with a JSON block:
{
  "status": "PASS" | "MINOR_ISSUES" | "MAJOR_ISSUES",
  "finding_count": N,
  "critical": N,
  "major": N,
  "minor": N,
  "next": "proceed" | "fix-and-rerun" | "escalate"
}
```

Haiku is fast and cheap. Use it as the first-pass filter. Average cost: 10-20K tokens per review.

### Step 5b: Escalation (if Haiku flags MAJOR_ISSUES)

If Haiku's JSON returns `status: MAJOR_ISSUES` or `critical > 0`:

Dispatch a second agent: **general-purpose**, **sonnet** or **opus** model. Same inputs plus Haiku's findings. Sonnet/opus produces the authoritative review and patch list.

If the issue is at the brief/aesthetic level (not just a code bug), the escalation may recommend:
- Re-invoking `frontend-design` to update the aesthetic direction
- Re-invoking `ux-brief` to revise the brief

This is rare — most issues are at the impl level and fix via develop agent.

### Step 6: Act on findings

Based on the review's `next` field:

| next | Action |
|---|---|
| `proceed` | Report: "Design review passed. Proceeding to browser-test." Shutdown dev server if this skill started it. |
| `fix-and-rerun` | Dispatch a **sonnet** fix agent with the specific patches from the review. After fixes, re-run Step 4-5 (screenshot + review). Max 2 iterations, then escalate. |
| `escalate` | Report findings to the caller (craft/develop/implement). User sees the review and decides: revise brief, revise impl, or accept as-is. |

### Step 7: Cleanup

```bash
# Stop dev server if this skill started it
if [ "$DEV_SERVER_STARTED" = true ]; then
  kill $DEV_PID 2>/dev/null
fi

# Screenshots are kept in .claude/plans/{feature-dir}/screenshots/ for traceability
```

## Output

- File: `.claude/plans/{feature-dir}/design-review.md`
- Screenshots: `.claude/plans/{feature-dir}/screenshots/`
- Return: status (PASS/MINOR/MAJOR), finding count, next action

## Integration with develop pipeline

`develop/SKILL.md` Step 3.75 (inserted between 3.5 post-develop review and 4 verification):

```
### Step 3.75: Design Review (conditional)

If .shared-state.md "Created / Modified Files" includes UI files (.tsx/.vue/.svelte):
  Invoke craft-skills:design-review

  Based on status:
  - PASS → continue to Step 4 Verification
  - MINOR_ISSUES → design-review dispatches fix agent automatically; re-enter this step after
  - MAJOR_ISSUES → STOP. Report to user, await guidance
```

## Fallbacks

| Missing | Behavior |
|---|---|
| Playwright MCP | Text-only fallback (DOM snapshot review). Cannot catch rendered-layout bugs. Log: "Playwright unavailable; design-review is text-only. Install @playwright/mcp for visual regression." |
| Haiku / any Claude API access | Skip skill. Log and proceed to browser-test — human catches issues there. |
| Login required, no test credentials | Pause and ask user to log in (per existing browser-test convention) |
| Dev server fails to start | Abort skill, report error, skip to Step 6 cleanup. Do NOT block pipeline — browser-test will surface the same issue functionally. |
| `.claude/aesthetic-direction.md` missing | Skip skill silently. Log: "No aesthetic direction. Run craft-skills:aesthetic-direction to enable design-review." |
| `ux-brief.md` missing | Run review against aesthetic-direction only. No success-criteria check, just regression heuristics. |

## Cost envelope

| Scenario | Tokens |
|---|---|
| Clean feature (PASS on first Haiku pass) | ~10-15K |
| Minor issues, one fix round (Haiku → sonnet fix → Haiku re-check) | ~40-60K |
| Major issues, escalated to Sonnet/Opus review | ~80-120K |

Typical: 15-20K / feature (most changes pass first round).

## Why Haiku-first, not Opus-first

Haiku-vision is ~8-10× cheaper than Opus-vision and, for the specific task of "does this screenshot match the design-contract and ux-brief success criteria," performs adequately on 70-80% of cases. Escalation to Sonnet/Opus happens only when Haiku's judgment is uncertain or flags MAJOR issues. This follows the same two-tier pattern as craft's Gemma-first + Sonnet-fallback for implementation.
