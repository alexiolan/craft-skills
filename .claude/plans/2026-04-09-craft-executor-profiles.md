# Craft Executor Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add four parallel `craft` variants (`/craft`, `/craft-duo`, `/craft-local`, `/craft-squad`) that let the user choose an executor mix per run. Route data-layer tasks to Codex in profiles that include codex, strip local LLM from the base `/craft` path, and preserve current behavior under `/craft-local`.

**Architecture:** Four thin wrapper skills delegate to a shared `_craft-core/` directory. A `.craft-profile` file at project root declares which executors are active for the current run. The `develop` skill reads the profile and routes data-layer tasks to Codex (via direct `codex exec` subprocess) instead of Claude sonnet agents when the profile includes codex. The `architect` skill and core skip local LLM calls when the profile excludes llm. Graph tools run in every variant unconditionally.

**Tech Stack:** Claude Code skills (markdown SKILL.md files), bash scripts, Codex CLI (`@openai/codex` v0.118+), JSON Schema for structured Codex output, git for commits and tags.

**Related spec:** `.claude/plans/specs/2026-04-09-craft-executor-profiles-design.md`

**Target version:** `1.0.26` → `1.1.0`

**Testing note:** This is a skills plugin, not traditional code. Most verification is file-presence checks, bash syntax checks, JSON schema validation, and targeted smoke tests by invoking the skills on a real small feature in an adjacent frontend project. Each phase ends with a commit.

---

## Phase 1: Shared core extraction + profile mechanism

**Intent:** Pull the existing `craft` pipeline logic into `_craft-core/` reference files and add `.craft-profile` read/write infrastructure. No behavior change — `/craft` should produce identical results after this phase.

### Task 1.1: Create the `_craft-core/` directory with reference files

**Files:**
- Create: `skills/_craft-core/core.md`
- Create: `skills/_craft-core/profiles.md`
- Create: `skills/_craft-core/codex-executor.md`
- Create: `skills/_craft-core/llm-gating.md`

- [ ] **Step 1: Create `skills/_craft-core/profiles.md`**

Write this content:

````markdown
# Craft Executor Profiles

This file is the authoritative reference for profile definitions. Read by wrappers and `develop` to determine which executors are active for a run.

## Profile values

| Value | Claude | Codex | Local LLM | Used by |
|---|---|---|---|---|
| `claude` | yes | no | no | `/craft` |
| `claude+codex` | yes | yes | no | `/craft-duo` |
| `claude+llm` | yes | no | yes | `/craft-local` |
| `claude+codex+llm` | yes | yes | yes | `/craft-squad` |

## `.craft-profile` file

Wrapper skills write the profile value as a single line (no trailing newline) to `.craft-profile` at the project root as their very first step:

```bash
echo -n "claude+codex" > "$PROJECT_ROOT/.craft-profile"
```

`develop`, `architect`, and `_craft-core/core.md` read it:

```bash
CRAFT_PROFILE=$(cat "$PROJECT_ROOT/.craft-profile" 2>/dev/null || echo "claude")
```

Default when missing: `claude` (backwards-compatible fallback).

## Gating helpers

```bash
# Does the profile include Codex?
case "$CRAFT_PROFILE" in
  *codex*) CODEX_ENABLED=1 ;;
  *)       CODEX_ENABLED=0 ;;
esac

# Does the profile include local LLM?
case "$CRAFT_PROFILE" in
  *llm*) LLM_ENABLED=1 ;;
  *)     LLM_ENABLED=0 ;;
esac
```

## Cleanup

`.craft-profile` is deleted alongside `.shared-state.md` at the end of `develop` Step 5 (cleanup).
````

- [ ] **Step 2: Create `skills/_craft-core/llm-gating.md`**

Write this content:

````markdown
# LLM Gating Rules

Local LLM (LM Studio) paths run only when the profile includes `llm`.

## Gated step: `architect` pre-exploration (Step 0)

Currently `architect/SKILL.md` runs an LLM availability check and optional background exploration via `llm-agent.sh`. Under profile gating:

```bash
CRAFT_PROFILE=$(cat "$PROJECT_ROOT/.craft-profile" 2>/dev/null || echo "claude")
case "$CRAFT_PROFILE" in
  *llm*)
    # existing LLM availability check + background llm-agent.sh dispatch
    ;;
  *)
    # skip — no LLM steps
    echo "LLM_SKIPPED_BY_PROFILE"
    ;;
esac
```

## Gated step: `develop` Step 3.5 (post-develop review)

Currently runs `llm-agent.sh` to review implementation files. Same gating pattern.

## Gated step: `craft` spec review (Step 1.10)

Currently runs `llm-review.sh` as a parallel supplementary review of the spec. Same gating pattern.

## Gated step: `craft` plan review (Step 2.4)

Currently runs `llm-review.sh` as a parallel supplementary review of the plan. Same gating pattern.

## Unloading

LM Studio keep-loaded / unload scripts run only when LLM was actually loaded. The guard is the same profile check — if LLM was skipped, don't call `llm-unload.sh`.

## What does NOT get gated

Graph tools (`code-review-graph` MCP) run in every profile. They are deterministic infrastructure, not AI. See `profiles.md`.
````

- [ ] **Step 3: Create `skills/_craft-core/codex-executor.md`**

Write this content:

````markdown
# Codex Executor Guide

Reference for how `develop` dispatches tasks to Codex when the profile includes codex. Used only by `develop`; other skills can ignore this file.

## When Codex runs

Profile-gated to `claude+codex` and `claude+codex+llm`:

```bash
case "$CRAFT_PROFILE" in
  *codex*) CODEX_ENABLED=1 ;;
  *)       CODEX_ENABLED=0 ;;
esac
```

If `CODEX_ENABLED=1`, Codex handles:
- Data layer tasks (types, services, queries, schemas, enums, mappers)
- Bulk mechanical fixes (lint/tsc repair sweeps)

All other task types stay on Claude regardless.

## Pre-flight check

Before dispatching any Codex task, run:

```bash
codex --version >/dev/null 2>&1 || {
  echo "ERROR: codex CLI not found."
  echo "Install: npm i -g @openai/codex"
  exit 1
}
```

No silent fallback to Claude. User explicitly chose a codex profile.

## Two-tier model routing

When Codex is routed a task, pick the model based on the target filename pattern:

| Target path glob | Model |
|---|---|
| `*/data/models/*.ts`, `*/data/enums/*.ts` | `codex-mini` |
| `*/data/schemas/*Schemas.ts` | `codex-mini` |
| `*/data/mappers/*.ts` | `codex-mini` |
| `*/data/infrastructure/*Service.ts` | `gpt-5-codex` |
| `*/data/queries/*Queries.ts` | `gpt-5-codex` |
| Bulk lint/tsc fix sweeps | `codex-mini` |

## Invocation shape

See `scripts/codex-dispatch.sh` for the canonical invocation. The invocation is:

```bash
codex exec \
  --full-auto \
  --sandbox workspace-write \
  -C "$PROJECT_ROOT" \
  --ephemeral \
  --output-schema "$CRAFT_SCRIPTS/codex-status-schema.json" \
  --output-last-message "$PROJECT_ROOT/.codex-output-$TASK_ID.json" \
  -m "$CODEX_MODEL" \
  - < "$PROJECT_ROOT/.codex-prompt-$TASK_ID.txt"
```

## Prompt template

See `skills/develop/codex-prompt.md` for the prompt template that `develop` fills in per task.

## Status protocol

Codex emits JSON conforming to `scripts/codex-status-schema.json` as its final message. `develop` reads `--output-last-message`, parses the JSON, and routes by status:

- `DONE` → verify shared-state updated, proceed
- `DONE_WITH_CONCERNS` → log concerns, decide if a fix agent is needed
- `NEEDS_CONTEXT` → provide missing context, re-dispatch
- `BLOCKED` → investigate, fix root cause, re-dispatch
- Invalid JSON → dispatch Claude sonnet reconcile agent
- Non-zero exit → dispatch Claude sonnet fallback agent for this task
````

- [ ] **Step 4: Create `skills/_craft-core/core.md`**

This file holds a pointer-style index of the pipeline steps and references the wrappers' entry points. The full pipeline logic stays in `craft/SKILL.md` for Phase 1 (refactoring happens in later tasks). Write this content:

````markdown
# Craft Core Pipeline (reference)

This directory contains the shared pipeline logic for the `craft` family of skills (`/craft`, `/craft-duo`, `/craft-local`, `/craft-squad`). Wrapper skills write a profile value to `.craft-profile` and then follow the pipeline defined here.

## Files in this directory

- `profiles.md` — profile definitions, `.craft-profile` protocol, gating helpers
- `llm-gating.md` — where and how local LLM steps are skipped per profile
- `codex-executor.md` — Codex dispatch reference used by `develop`
- `core.md` — this file (pipeline index)

## Pipeline phases

The craft pipeline has five phases. All wrappers run the same phases; profile gating affects which substeps run inside each phase.

1. **Brainstorm** — collaborative design exploration with the user, spec writing, spec review
2. **Plan** — implementation plan creation, plan review
3. **Develop** — dispatch implementation tasks (profile-aware executor routing)
4. **Test** — browser testing
5. **Report** — summary

## Profile-gated substeps (summary)

| Phase / Step | `claude` | `claude+codex` | `claude+llm` | `claude+codex+llm` |
|---|---|---|---|---|
| 1.1 LLM pre-exploration | skip | skip | run | run |
| 1.10 LLM spec review | skip | skip | run | run |
| 2.4 LLM plan review | skip | skip | run | run |
| 3 Data layer dispatch | Claude sonnet | **Codex** | Claude sonnet | **Codex** |
| 3 UI dispatch | Claude sonnet | Claude sonnet | Claude sonnet | Claude sonnet |
| 3 Integration dispatch | Claude opus | Claude opus | Claude opus | Claude opus |
| 3.5 LLM post-develop review | skip | skip | run | run |
| 3.5 Codex adversarial review | skip | run (if plugin installed) | skip | run (if plugin installed) |

## Graph tools (always on)

Graph tools (`code-review-graph` MCP) run in every variant unconditionally. They are deterministic infrastructure, not AI.

## Wrapper responsibilities

Each wrapper SKILL.md is ~30 lines and does exactly two things:

1. Write the profile value to `.craft-profile`
2. Instruct Claude to follow the canonical pipeline (currently in `craft/SKILL.md`; in future refactors, may move here)

## Invariant

Never delete `.craft-profile` before `develop` finishes. It is cleaned up as part of `develop` Step 5 cleanup, alongside `.shared-state.md`.
````

- [ ] **Step 5: Verify all four files exist**

```bash
ls -la /Users/alex/Projects/frontend/craft-skills/skills/_craft-core/
```

Expected output includes: `core.md`, `profiles.md`, `codex-executor.md`, `llm-gating.md`.

- [ ] **Step 6: Verify no `SKILL.md` in `_craft-core/` (skill discovery should not pick it up as a user-facing skill)**

```bash
find /Users/alex/Projects/frontend/craft-skills/skills/_craft-core -name "SKILL.md"
```

Expected output: empty (no results).

- [ ] **Step 7: Commit**

```bash
cd /Users/alex/Projects/frontend/craft-skills
git add skills/_craft-core/
git commit -m "feat(craft-core): add _craft-core reference files for executor profiles"
```

---

### Task 1.2: Add profile read/write to `craft/SKILL.md`

Base `/craft` writes `claude` to `.craft-profile` at the start of its execution. Other wrappers (added later) will do the same with their own profile values. This task only modifies `craft/SKILL.md`.

**Files:**
- Modify: `skills/craft/SKILL.md`

- [ ] **Step 1: Add a profile-write step at the very top of Phase 1**

Open `skills/craft/SKILL.md`. Find this line (currently at line ~43):

```markdown
## Phase 1: Brainstorm

### 1.1 Explore Context
```

Replace it with:

```markdown
## Phase 1: Brainstorm

### 1.0 Set Executor Profile

First action in the pipeline. Write the profile marker so later steps can gate behavior correctly.

```bash
echo -n "claude" > .craft-profile
```

This is a backwards-compatible no-op today (the `claude` profile keeps current behavior via this commit's guards). In later phases, LLM gating and Codex dispatch will branch on this file.

### 1.1 Explore Context
```

- [ ] **Step 2: Verify the edit was applied**

```bash
grep -n "### 1.0 Set Executor Profile" /Users/alex/Projects/frontend/craft-skills/skills/craft/SKILL.md
```

Expected output: one match with line number around 43-45.

- [ ] **Step 3: Commit**

```bash
cd /Users/alex/Projects/frontend/craft-skills
git add skills/craft/SKILL.md
git commit -m "feat(craft): write .craft-profile marker at pipeline start"
```

---

### Task 1.3: Add profile cleanup to `develop/SKILL.md`

When develop finishes successfully, it deletes `.shared-state.md`. Extend the cleanup to also delete `.craft-profile`.

**Files:**
- Modify: `skills/develop/SKILL.md`

- [ ] **Step 1: Find the Step 5 cleanup section and add profile cleanup**

Open `skills/develop/SKILL.md`. Find this block:

```markdown
## Step 5: Cleanup

After a successful build:

1. Delete `.shared-state.md`
2. Report a summary of all changes made, files created/modified, and any decisions worth noting
```

Replace with:

```markdown
## Step 5: Cleanup

After a successful build:

1. Delete `.shared-state.md`
2. Delete `.craft-profile` (if it exists — may be missing when `develop` is invoked standalone)
3. Report a summary of all changes made, files created/modified, and any decisions worth noting
```

- [ ] **Step 2: Verify the edit**

```bash
grep -n "Delete .craft-profile" /Users/alex/Projects/frontend/craft-skills/skills/develop/SKILL.md
```

Expected output: one match.

- [ ] **Step 3: Commit**

```bash
cd /Users/alex/Projects/frontend/craft-skills
git add skills/develop/SKILL.md
git commit -m "feat(develop): clean up .craft-profile alongside .shared-state.md"
```

---

## Phase 2: Strip LLM from base `/craft` + add `/craft-local`

**Intent:** Base `/craft` no longer runs LLM-related steps. Users who want the current LLM-assisted behavior invoke `/craft-local` instead.

### Task 2.1: Gate LLM steps in `craft/SKILL.md` on profile

Add `case` guards around every bash block that calls `llm-agent.sh`, `llm-review.sh`, or `llm-unload.sh`.

**Files:**
- Modify: `skills/craft/SKILL.md` (four bash blocks: 1.1 Step 1, 1.1 Step 2, 1.10 parallel LLM review, 2.4 parallel LLM review)

- [ ] **Step 1: Gate Step 1 of section 1.1 (LM Studio availability check)**

Find the bash block that starts with `CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "llm-agent.sh"` in section 1.1 Step 1. Wrap it with a profile check:

```markdown
**Step 1 — Check LM Studio (Bash tool, wait for result):**

Only runs when profile includes `llm`. Gate:

```bash
CRAFT_PROFILE=$(cat .craft-profile 2>/dev/null || echo "claude")
case "$CRAFT_PROFILE" in
  *llm*)
    CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "llm-agent.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1) && curl -s --max-time 2 ${LLM_URL:-http://127.0.0.1:1234} > /dev/null 2>&1 && echo "LLM_AVAILABLE:$CRAFT_SCRIPTS" || echo "LLM_UNAVAILABLE"
    ;;
  *)
    echo "LLM_SKIPPED_BY_PROFILE"
    ;;
esac
```
```

- [ ] **Step 2: Gate Step 2 of section 1.1 (LLM exploration in background)**

Find the `**Step 2 — Start LLM exploration in background (if available):**` section. Change the instruction to:

```markdown
**Step 2 — Start LLM exploration in background (if available AND profile includes llm):**

Run only if Step 1 returned `LLM_AVAILABLE` (which only happens when the profile includes `llm`). If Step 1 returned `LLM_SKIPPED_BY_PROFILE` or `LLM_UNAVAILABLE`, skip this step.

If eligible, run with Bash tool (`run_in_background: true`, timeout 300000ms):

```bash
bash "$CRAFT_SCRIPTS/llm-agent.sh" "Investigate [2-3 domain paths relevant to the feature] for a [feature] feature. Check: 1) What types/services exist in these domains 2) How forms and validation are set up 3) Any related API endpoints. Give a structured summary." <project-root>
```

Do NOT unload — more LLM steps follow (spec review 1.10, plan review 2.4).
```

- [ ] **Step 3: Gate section 1.10 (parallel LLM spec review)**

Find the block containing `bash "$CRAFT_SCRIPTS/llm-review.sh" <spec-file-path>`. Replace with:

```markdown
**Parallel local LLM review (profile-gated):**

Only runs when profile includes `llm`. Run with Bash tool (`run_in_background: true`, timeout 300000ms) in parallel with the opus agent:

```bash
CRAFT_PROFILE=$(cat .craft-profile 2>/dev/null || echo "claude")
case "$CRAFT_PROFILE" in
  *llm*)
    CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "llm-agent.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1) && bash "$CRAFT_SCRIPTS/llm-review.sh" <spec-file-path> "completeness, feasibility, backend alignment, DDD compliance"
    ;;
  *)
    echo "LLM_SPEC_REVIEW_SKIPPED"
    ;;
esac
```

Do NOT unload — more LLM steps may follow.
```

- [ ] **Step 4: Gate section 2.4 (parallel LLM plan review + unload)**

Find the LLM review bullet in section 2.4. Replace with:

```markdown
- **LLM review (profile-gated):** Run with Bash tool (`run_in_background: true`, timeout 300000ms):
  ```bash
  CRAFT_PROFILE=$(cat .craft-profile 2>/dev/null || echo "claude")
  case "$CRAFT_PROFILE" in
    *llm*)
      CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "llm-agent.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1) && bash "$CRAFT_SCRIPTS/llm-review.sh" <plan-file-path> "spec coverage, task ordering, completeness, risk areas"
      bash "$CRAFT_SCRIPTS/llm-unload.sh"
      ;;
    *)
      echo "LLM_PLAN_REVIEW_SKIPPED"
      ;;
  esac
  ```
```

- [ ] **Step 5: Verify all four gate sites are in place**

```bash
grep -c "CRAFT_PROFILE=\$(cat .craft-profile" /Users/alex/Projects/frontend/craft-skills/skills/craft/SKILL.md
```

Expected output: `4` (one per gated bash block).

- [ ] **Step 6: Commit**

```bash
cd /Users/alex/Projects/frontend/craft-skills
git add skills/craft/SKILL.md
git commit -m "feat(craft): gate LLM steps on profile, default claude skips all LLM work"
```

---

### Task 2.2: Gate LLM steps in `architect/SKILL.md` on profile

The architect skill runs LLM pre-exploration in Step 0. Same gating pattern.

**Files:**
- Modify: `skills/architect/SKILL.md`

- [ ] **Step 1: Gate Step 0 Step 1 (LM Studio availability check)**

Find the bash block at `**Step 1 — Check LM Studio (Bash tool, wait for result):**` in Step 0. Replace with the profile-gated version:

```markdown
**Step 1 — Check LM Studio (Bash tool, wait for result):**

Profile-gated. Only runs when profile includes `llm`:

```bash
CRAFT_PROFILE=$(cat .craft-profile 2>/dev/null || echo "claude")
case "$CRAFT_PROFILE" in
  *llm*)
    CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "llm-agent.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1) && curl -s --max-time 2 ${LLM_URL:-http://127.0.0.1:1234} > /dev/null 2>&1 && echo "LLM_AVAILABLE:$CRAFT_SCRIPTS" || echo "LLM_UNAVAILABLE"
    ;;
  *)
    echo "LLM_SKIPPED_BY_PROFILE"
    ;;
esac
```
```

- [ ] **Step 2: Gate Step 0 Step 2 (LLM exploration)**

Find `**Step 2 — Start LLM exploration in background (if available):**` and change the instruction to:

```markdown
**Step 2 — Start LLM exploration in background (if available AND profile includes llm):**

Skip if Step 1 returned `LLM_SKIPPED_BY_PROFILE` or `LLM_UNAVAILABLE`. Otherwise run:

```bash
bash "$CRAFT_SCRIPTS/llm-agent.sh" "Investigate [2-3 domain paths] for a [feature] feature. Check: types, services, components, patterns, API endpoints. Structured summary." <project-root>
```

When standalone, unload after only if LLM was actually loaded:

```bash
case "$CRAFT_PROFILE" in
  *llm*) bash "$CRAFT_SCRIPTS/llm-unload.sh" ;;
esac
```

When part of craft pipeline, skip unloading.
```

- [ ] **Step 3: Verify**

```bash
grep -c "CRAFT_PROFILE=\$(cat .craft-profile" /Users/alex/Projects/frontend/craft-skills/skills/architect/SKILL.md
```

Expected output: `1` (one profile check; the inner unload check reuses the variable already in scope).

- [ ] **Step 4: Commit**

```bash
cd /Users/alex/Projects/frontend/craft-skills
git add skills/architect/SKILL.md
git commit -m "feat(architect): gate LLM pre-exploration on profile"
```

---

### Task 2.3: Gate LLM review in `develop/SKILL.md` Step 3.5 on profile

**Files:**
- Modify: `skills/develop/SKILL.md`

- [ ] **Step 1: Gate Step A (Check LM Studio)**

Find `**Step A — Check LM Studio (Bash tool, wait for result):**` in Step 3.5. Replace with:

```markdown
**Step A — Check LM Studio (Bash tool, wait for result):**

Profile-gated. Only runs when profile includes `llm`:

```bash
CRAFT_PROFILE=$(cat .craft-profile 2>/dev/null || echo "claude")
case "$CRAFT_PROFILE" in
  *llm*)
    CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "llm-agent.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1) && curl -s --max-time 2 ${LLM_URL:-http://127.0.0.1:1234} > /dev/null 2>&1 && echo "LLM_AVAILABLE:$CRAFT_SCRIPTS" || echo "LLM_UNAVAILABLE"
    ;;
  *)
    echo "LLM_SKIPPED_BY_PROFILE"
    ;;
esac
```
```

- [ ] **Step 2: Gate Step B (LLM review in background)**

Find `**Step B — Start LLM review in background (if available):**` and update the instruction to:

```markdown
**Step B — Start LLM review in background (if available AND profile includes llm):**

Skip if Step A returned `LLM_SKIPPED_BY_PROFILE` or `LLM_UNAVAILABLE`. Otherwise run with Bash tool (`run_in_background: true`, timeout 300000ms):

```bash
bash "$CRAFT_SCRIPTS/llm-agent.sh" "Review these files for bugs, missing imports, type mismatches, pattern violations, and DDD boundary violations: [file list from .shared-state.md or graph results]." <project-root>
```

Then unload only if LLM actually ran:

```bash
case "$CRAFT_PROFILE" in
  *llm*) bash "$CRAFT_SCRIPTS/llm-unload.sh" ;;
esac
```

If Step A returned `LLM_UNAVAILABLE` (but profile includes llm), fall back to reading only integration/wiring files.

If Step A returned `LLM_SKIPPED_BY_PROFILE`, the graph review in Step C is the only post-develop review — no file-reading fallback.
```

- [ ] **Step 3: Verify**

```bash
grep -c "CRAFT_PROFILE=\$(cat .craft-profile" /Users/alex/Projects/frontend/craft-skills/skills/develop/SKILL.md
```

Expected output: `1` (profile check at top of Step 3.5; reused inside).

- [ ] **Step 4: Commit**

```bash
cd /Users/alex/Projects/frontend/craft-skills
git add skills/develop/SKILL.md
git commit -m "feat(develop): gate LLM post-develop review on profile"
```

---

### Task 2.4: Create `/craft-local` wrapper

**Files:**
- Create: `skills/craft-local/SKILL.md`

- [ ] **Step 1: Create the wrapper skill file**

Write this exact content to `skills/craft-local/SKILL.md`:

````markdown
---
name: craft-local
description: "Same as /craft but with local LLM review steps enabled. Use when you have LM Studio running and want LLM-assisted spec/plan/post-develop reviews. Preserves pre-1.1 craft behavior."
---

# Craft (local LLM variant)

Full design-first pipeline with LM Studio as a supplementary review agent. Identical to `/craft` except that LLM pre-exploration, spec review, plan review, and post-develop review steps all run.

**Profile:** `claude+llm`

**Pipeline:** Brainstorm → Plan → Develop → Browser Test → Report (same as `/craft`)

## How this wrapper works

This wrapper is ~1 step of delegation. The actual pipeline logic lives in `skills/craft/SKILL.md`. This file writes the profile marker, then instructs you to follow the craft pipeline.

## Step 1: Write profile marker

```bash
echo -n "claude+llm" > .craft-profile
```

## Step 2: Follow the craft pipeline

Read `skills/craft/SKILL.md` from this plugin and follow every phase exactly as written. The profile gating in that file ensures LLM steps run when profile is `claude+llm`.

The user input is: `$ARGUMENTS`

Pass the input through to the craft pipeline as if the user had invoked `/craft` directly.

## Notes

- Requires LM Studio running at `${LLM_URL:-http://127.0.0.1:1234}`
- Does NOT require Codex CLI
- All LLM steps will run; expect ~30% longer runs than `/craft` in exchange for deeper review
````

- [ ] **Step 2: Verify the file exists and has valid frontmatter**

```bash
head -5 /Users/alex/Projects/frontend/craft-skills/skills/craft-local/SKILL.md
```

Expected output: the frontmatter block starting with `---` and ending with `---`, containing `name: craft-local`.

- [ ] **Step 3: Commit**

```bash
cd /Users/alex/Projects/frontend/craft-skills
git add skills/craft-local/
git commit -m "feat(craft-local): add wrapper skill for claude+llm profile"
```

---

### Task 2.5: Smoke test `/craft` and `/craft-local` gating behavior

This is a manual verification, not an automated test. Record the result before proceeding.

- [ ] **Step 1: In a separate terminal, stop LM Studio if it is running**

Or simply ensure `curl http://127.0.0.1:1234` fails.

- [ ] **Step 2: In an adjacent frontend project, invoke `/craft` with a trivial feature request**

Example prompt: "Add a disabled 'Coming soon' button under the profile dropdown."

- [ ] **Step 3: Verify `/craft` does NOT attempt to contact LM Studio**

In the session logs, confirm there are no references to `llm-agent.sh` or `llm-review.sh` being executed. The bash blocks should show `LLM_SKIPPED_BY_PROFILE` output.

- [ ] **Step 4: Verify `.craft-profile` contains `claude`**

```bash
cat <project-root>/.craft-profile
```

Expected output: `claude`

- [ ] **Step 5: Let the craft run complete through brainstorm phase only, then abort before committing code**

- [ ] **Step 6: Start LM Studio**

- [ ] **Step 7: Invoke `/craft-local` on the same trivial feature**

- [ ] **Step 8: Verify `/craft-local` DOES contact LM Studio**

Session logs should show `LLM_AVAILABLE:...` and `llm-agent.sh` being dispatched.

- [ ] **Step 9: Verify `.craft-profile` contains `claude+llm`**

```bash
cat <project-root>/.craft-profile
```

Expected output: `claude+llm`

- [ ] **Step 10: Abort and clean up**

```bash
rm -f <project-root>/.craft-profile <project-root>/.shared-state.md
```

No commit for this task — smoke test only.

---

## Phase 3: AGENTS.md generation

**Intent:** Generate `AGENTS.md` from `CLAUDE.md` so Codex can read project conventions. Wire into bootstrap flow.

### Task 3.1: Create `scripts/sync-agents-md.sh`

**Files:**
- Create: `scripts/sync-agents-md.sh`

- [ ] **Step 1: Write the script**

Write this exact content to `/Users/alex/Projects/frontend/craft-skills/scripts/sync-agents-md.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# sync-agents-md.sh
# Generates AGENTS.md from CLAUDE.md so Codex has the same project context as Claude.
#
# Usage:
#   sync-agents-md.sh <project-root>
#
# Exits 0 on success, non-zero on failure. Idempotent.

PROJECT_ROOT="${1:-}"
if [[ -z "$PROJECT_ROOT" ]]; then
  echo "ERROR: project root required as first argument" >&2
  echo "Usage: sync-agents-md.sh <project-root>" >&2
  exit 2
fi

if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "ERROR: project root does not exist: $PROJECT_ROOT" >&2
  exit 2
fi

CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
PARENT_CLAUDE_MD=""
AGENTS_MD="$PROJECT_ROOT/AGENTS.md"

# Find parent CLAUDE.md if it exists (one level up or in .claude/ sibling)
if [[ -f "$PROJECT_ROOT/../.claude/CLAUDE.md" ]]; then
  PARENT_CLAUDE_MD="$PROJECT_ROOT/../.claude/CLAUDE.md"
elif [[ -f "$PROJECT_ROOT/../CLAUDE.md" ]]; then
  PARENT_CLAUDE_MD="$PROJECT_ROOT/../CLAUDE.md"
fi

if [[ ! -f "$CLAUDE_MD" ]]; then
  echo "WARN: no CLAUDE.md at $CLAUDE_MD — AGENTS.md not generated" >&2
  exit 1
fi

{
  cat <<'PREAMBLE'
# AGENTS.md

> This file is generated from CLAUDE.md by `scripts/sync-agents-md.sh`.
> Do NOT edit directly. Edit CLAUDE.md and re-run the sync script.

## Codex-specific constraints

These rules apply to all Codex executions in this project:

- Do NOT reformat existing code. Only change lines directly related to the task.
- Respect existing formatting and patterns, even if they differ from your defaults.
- Use named exports, not default exports.
- Follow the DDD structure strictly. Never import across business domain boundaries.
- When creating new files, match the style of existing files in the same directory.
- Never add files outside the scope of your specific task.
- Append your outputs (created files, exports, dependencies) to `.shared-state.md` before exiting.

---

PREAMBLE

  if [[ -n "$PARENT_CLAUDE_MD" ]]; then
    echo "## Parent CLAUDE.md"
    echo ""
    cat "$PARENT_CLAUDE_MD"
    echo ""
    echo "---"
    echo ""
  fi

  echo "## Project CLAUDE.md"
  echo ""
  cat "$CLAUDE_MD"
} > "$AGENTS_MD"

echo "AGENTS.md written to $AGENTS_MD"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x /Users/alex/Projects/frontend/craft-skills/scripts/sync-agents-md.sh
```

- [ ] **Step 3: Verify bash syntax is valid**

```bash
bash -n /Users/alex/Projects/frontend/craft-skills/scripts/sync-agents-md.sh && echo "OK"
```

Expected output: `OK`

- [ ] **Step 4: Run against an adjacent frontend project as a smoke test**

Pick any frontend project in `/Users/alex/Projects/frontend/` that has a `CLAUDE.md`. Replace `<project>` below:

```bash
bash /Users/alex/Projects/frontend/craft-skills/scripts/sync-agents-md.sh /Users/alex/Projects/frontend/<project>
```

Expected: exit 0, prints `AGENTS.md written to ...`.

- [ ] **Step 5: Verify the generated AGENTS.md**

```bash
head -30 /Users/alex/Projects/frontend/<project>/AGENTS.md
```

Expected: the preamble block with Codex constraints, followed by CLAUDE.md content.

- [ ] **Step 6: Remove the test AGENTS.md**

```bash
rm /Users/alex/Projects/frontend/<project>/AGENTS.md
```

- [ ] **Step 7: Commit**

```bash
cd /Users/alex/Projects/frontend/craft-skills
git add scripts/sync-agents-md.sh
git commit -m "feat(scripts): add sync-agents-md.sh for generating Codex context"
```

---

### Task 3.2: Wire `sync-agents-md.sh` into `bootstrap/SKILL.md`

**Files:**
- Modify: `skills/bootstrap/SKILL.md`

- [ ] **Step 1: Add an AGENTS.md generation section**

Open `skills/bootstrap/SKILL.md`. After the `## Available Skills` section ends (before `## DDD-Aware Triggers`), add this new section:

```markdown
## Codex Context Setup

If the project uses `/craft-duo` or `/craft-squad` (profiles that include Codex), an `AGENTS.md` file must exist at the project root. Codex reads it the same way Claude reads `CLAUDE.md`.

On session start, the bootstrap hook regenerates `AGENTS.md` from `CLAUDE.md` if:
- `AGENTS.md` is missing, OR
- `CLAUDE.md` has been modified since `AGENTS.md` was last generated

This keeps the two files in sync without manual intervention. The generator lives at `scripts/sync-agents-md.sh` and is idempotent.

Users who only use `/craft` or `/craft-local` can ignore `AGENTS.md`; it is harmless if present.

```

- [ ] **Step 2: Verify the insertion**

```bash
grep -n "Codex Context Setup" /Users/alex/Projects/frontend/craft-skills/skills/bootstrap/SKILL.md
```

Expected output: one match.

- [ ] **Step 3: Commit**

```bash
cd /Users/alex/Projects/frontend/craft-skills
git add skills/bootstrap/SKILL.md
git commit -m "docs(bootstrap): document AGENTS.md generation for Codex profiles"
```

---

## Phase 4: Codex dispatch infrastructure

**Intent:** Build the self-contained pieces needed to actually run `codex exec` from `develop`: status schema, prompt template, dispatch helper script.

### Task 4.1: Create `scripts/codex-status-schema.json`

**Files:**
- Create: `scripts/codex-status-schema.json`

- [ ] **Step 1: Write the JSON Schema**

Write this exact content to `/Users/alex/Projects/frontend/craft-skills/scripts/codex-status-schema.json`:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Codex Task Status",
  "type": "object",
  "required": ["status", "summary", "files_changed", "exports_added"],
  "properties": {
    "status": {
      "type": "string",
      "enum": ["DONE", "DONE_WITH_CONCERNS", "NEEDS_CONTEXT", "BLOCKED"],
      "description": "Outcome of the task"
    },
    "summary": {
      "type": "string",
      "description": "One- or two-sentence summary of what was done"
    },
    "files_changed": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Absolute or project-relative paths of all files created or modified"
    },
    "exports_added": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Named exports added (type, class, function, or const names). Empty array if none."
    },
    "dependencies_added": {
      "type": "array",
      "items": { "type": "string" },
      "description": "npm packages added to package.json. Empty array if none."
    },
    "concerns": {
      "type": "string",
      "description": "When status is DONE_WITH_CONCERNS, describe the concerns. Empty string otherwise."
    },
    "notes": {
      "type": "string",
      "description": "Optional free-form notes for the orchestrator"
    }
  }
}
```

- [ ] **Step 2: Verify JSON is valid**

```bash
python3 -c "import json; json.load(open('/Users/alex/Projects/frontend/craft-skills/scripts/codex-status-schema.json'))" && echo "VALID JSON"
```

Expected output: `VALID JSON`

- [ ] **Step 3: Commit**

```bash
cd /Users/alex/Projects/frontend/craft-skills
git add scripts/codex-status-schema.json
git commit -m "feat(scripts): add codex-status-schema.json for structured task output"
```

---

### Task 4.2: Create `skills/develop/codex-prompt.md` template

**Files:**
- Create: `skills/develop/codex-prompt.md`

- [ ] **Step 1: Write the template**

Write this exact content:

````markdown
# Codex Task Prompt Template

This is the prompt template that `develop` fills in and pipes to `codex exec` via stdin when dispatching a data-layer or bulk-fix task to Codex.

The orchestrator replaces `{{...}}` placeholders with task-specific values at dispatch time.

---

You are an autonomous implementation agent working inside an existing DDD-first frontend codebase. You must follow the project conventions strictly. The project's architectural rules are in `AGENTS.md` at the project root — read it first.

## Your task

{{TASK_DESCRIPTION}}

## Target files

{{FILE_LIST}}

## Architecture decisions (from the plan)

{{ARCHITECTURE_DECISIONS}}

## Pattern references (study these first, then mirror their style)

{{PATTERN_REFERENCES}}

## Current shared state (what other agents have built in this run)

```markdown
{{SHARED_STATE_CONTENTS}}
```

## Hard constraints

1. **Do NOT reformat unrelated code.** Only change lines directly related to your task.
2. **Do NOT add files outside the task scope.** Stick to the target file list above.
3. **Respect existing patterns.** Match naming, exports, error handling, and layout conventions from the pattern references.
4. **Named exports only.** No default exports.
5. **Do NOT import across business domain boundaries.** Shared code lives in `src/domain/shared/`, `src/domain/network/`, or `src/domain/forms/`.
6. **Append your outputs to `.shared-state.md`.** Before exiting, update these sections:
   - `## Created / Modified Files` — one bullet per file: `- path (exports: Name1, Name2)`
   - `## Shared Types & Interfaces` — one bullet per shared type: `- TypeName — path — brief description`
   - `## Dependencies Added` — one bullet per dependency (or leave unchanged if none)
   - `## Notes & Warnings` — anything other agents should know

## Required output

Your **final message** MUST be a single JSON object conforming to this schema:

```json
{
  "status": "DONE" | "DONE_WITH_CONCERNS" | "NEEDS_CONTEXT" | "BLOCKED",
  "summary": "one sentence describing what you did",
  "files_changed": ["path/to/file1.ts", "path/to/file2.ts"],
  "exports_added": ["TypeName", "functionName"],
  "dependencies_added": [],
  "concerns": "",
  "notes": ""
}
```

Use `DONE` if the task is complete and you have no concerns.
Use `DONE_WITH_CONCERNS` if you finished but want to flag something (put details in `concerns`).
Use `NEEDS_CONTEXT` if you cannot complete without more information from the orchestrator.
Use `BLOCKED` if you cannot proceed due to an error, conflict, or contradiction in the instructions.

Do not emit any text after the JSON. The JSON must be the last thing in your output.
````

- [ ] **Step 2: Verify the file exists**

```bash
ls -la /Users/alex/Projects/frontend/craft-skills/skills/develop/codex-prompt.md
```

Expected: file exists with non-zero size.

- [ ] **Step 3: Commit**

```bash
cd /Users/alex/Projects/frontend/craft-skills
git add skills/develop/codex-prompt.md
git commit -m "feat(develop): add codex-prompt.md template for Codex dispatches"
```

---

### Task 4.3: Create `scripts/codex-dispatch.sh` helper

A bash helper that encapsulates the `codex exec` invocation. `develop` calls this script per task instead of re-constructing the full command every time.

**Files:**
- Create: `scripts/codex-dispatch.sh`

- [ ] **Step 1: Write the script**

Write this exact content to `/Users/alex/Projects/frontend/craft-skills/scripts/codex-dispatch.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# codex-dispatch.sh
# Dispatches a single task to Codex via codex exec.
#
# Usage:
#   codex-dispatch.sh <project-root> <task-id> <model> <prompt-file>
#
# Arguments:
#   project-root  — absolute path to the project root
#   task-id       — unique task identifier (used for output filenames)
#   model         — codex model name (e.g. codex-mini, gpt-5-codex)
#   prompt-file   — absolute path to a file containing the filled-in prompt
#
# Output files written to <project-root>:
#   .codex-output-<task-id>.json — Codex's final structured JSON message
#
# Exit codes:
#   0 — Codex exited successfully (check JSON status for task outcome)
#   2 — invocation error (bad args, missing codex CLI)
#   other — Codex exited non-zero (fallback needed)

PROJECT_ROOT="${1:-}"
TASK_ID="${2:-}"
CODEX_MODEL="${3:-gpt-5-codex}"
PROMPT_FILE="${4:-}"

if [[ -z "$PROJECT_ROOT" || -z "$TASK_ID" || -z "$PROMPT_FILE" ]]; then
  echo "ERROR: usage: codex-dispatch.sh <project-root> <task-id> <model> <prompt-file>" >&2
  exit 2
fi

if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "ERROR: project root does not exist: $PROJECT_ROOT" >&2
  exit 2
fi

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "ERROR: prompt file does not exist: $PROMPT_FILE" >&2
  exit 2
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "ERROR: codex CLI not found in PATH." >&2
  echo "Install: npm i -g @openai/codex" >&2
  exit 2
fi

# Locate the craft-skills scripts directory (this script's directory)
CRAFT_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$CRAFT_SCRIPTS/codex-status-schema.json"

if [[ ! -f "$SCHEMA_FILE" ]]; then
  echo "ERROR: schema file missing: $SCHEMA_FILE" >&2
  exit 2
fi

OUTPUT_FILE="$PROJECT_ROOT/.codex-output-$TASK_ID.json"

# Run Codex. Pipe prompt via stdin.
codex exec \
  --full-auto \
  --sandbox workspace-write \
  -C "$PROJECT_ROOT" \
  --ephemeral \
  --output-schema "$SCHEMA_FILE" \
  --output-last-message "$OUTPUT_FILE" \
  -m "$CODEX_MODEL" \
  - < "$PROMPT_FILE"

CODEX_EXIT=$?

if [[ $CODEX_EXIT -ne 0 ]]; then
  echo "WARN: codex exec exited with code $CODEX_EXIT for task $TASK_ID" >&2
  exit $CODEX_EXIT
fi

if [[ ! -f "$OUTPUT_FILE" ]]; then
  echo "WARN: codex exec produced no output file for task $TASK_ID" >&2
  exit 1
fi

echo "Codex task $TASK_ID complete. Output: $OUTPUT_FILE"
exit 0
```

- [ ] **Step 2: Make executable**

```bash
chmod +x /Users/alex/Projects/frontend/craft-skills/scripts/codex-dispatch.sh
```

- [ ] **Step 3: Syntax check**

```bash
bash -n /Users/alex/Projects/frontend/craft-skills/scripts/codex-dispatch.sh && echo "OK"
```

Expected output: `OK`

- [ ] **Step 4: Run with bad args to verify error handling**

```bash
bash /Users/alex/Projects/frontend/craft-skills/scripts/codex-dispatch.sh 2>&1 || echo "exit: $?"
```

Expected output includes `ERROR: usage:` and `exit: 2`.

- [ ] **Step 5: Commit**

```bash
cd /Users/alex/Projects/frontend/craft-skills
git add scripts/codex-dispatch.sh
git commit -m "feat(scripts): add codex-dispatch.sh helper for codex exec invocations"
```

---

## Phase 5: Codex routing in `develop/SKILL.md`

**Intent:** Wire Codex into `develop` Step 2 task dispatch. When profile includes codex, route data-layer and bulk-fix tasks to Codex via `codex-dispatch.sh`; keep UI and integration on Claude.

### Task 5.1: Add Codex pre-flight check to `develop/SKILL.md`

**Files:**
- Modify: `skills/develop/SKILL.md`

- [ ] **Step 1: Add a pre-flight section before Step 1**

Find `## Step 1: Initialize Shared State` in `skills/develop/SKILL.md`. Immediately BEFORE it, insert this new section:

```markdown
## Step 0: Pre-flight Check (profile-aware)

Run this as a single self-contained bash block via the Bash tool. It reads the profile marker, verifies Codex (if needed), and regenerates `AGENTS.md` (if needed). All state is local to this block — nothing is expected to persist to subsequent blocks.

```bash
CRAFT_PROFILE=$(cat .craft-profile 2>/dev/null || echo "claude")
echo "Profile: $CRAFT_PROFILE"

case "$CRAFT_PROFILE" in
  *codex*)
    # Verify Codex CLI is installed
    if ! command -v codex >/dev/null 2>&1; then
      echo "ERROR: codex CLI not found in PATH."
      echo "The active profile ($CRAFT_PROFILE) requires Codex."
      echo "Install: npm i -g @openai/codex"
      echo "Then run: codex login"
      exit 1
    fi

    # Regenerate AGENTS.md if missing or stale
    CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "sync-agents-md.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1)
    if [[ -z "$CRAFT_SCRIPTS" ]]; then
      echo "ERROR: craft-skills scripts directory not found"
      exit 1
    fi
    if [[ ! -f "AGENTS.md" ]] || [[ "CLAUDE.md" -nt "AGENTS.md" ]]; then
      bash "$CRAFT_SCRIPTS/sync-agents-md.sh" "$PWD"
    fi
    ;;
esac
```

Fail loudly if pre-flight fails. No silent fallback — the user explicitly chose a codex profile.

```

- [ ] **Step 2: Verify the section was added**

```bash
grep -n "## Step 0: Pre-flight Check" /Users/alex/Projects/frontend/craft-skills/skills/develop/SKILL.md
```

Expected: one match.

- [ ] **Step 3: Commit**

```bash
cd /Users/alex/Projects/frontend/craft-skills
git add skills/develop/SKILL.md
git commit -m "feat(develop): add pre-flight check for codex profile"
```

---

### Task 5.2: Add Codex routing logic to `develop/SKILL.md` Step 2

**Files:**
- Modify: `skills/develop/SKILL.md`

- [ ] **Step 1: Extend Step 2's model selection table and add the Codex routing rules**

Find the `**Model selection per task type:**` block in Step 2. Replace the table and the paragraph below it with:

```markdown
**Executor selection per task type (profile-aware):**

| Task Type | `claude` / `claude+llm` | `claude+codex` / `claude+codex+llm` |
|---|---|---|
| Data layer (types, services, queries, schemas, enums, mappers) | Claude **sonnet** | **Codex** (two-tier, see below) |
| UI components (feature components, reusable UI) | Claude **sonnet** | Claude **sonnet** |
| Integration (wiring, routing, cross-component state) | Claude **opus** | Claude **opus** |
| Bulk mechanical fixes (lint/tsc repair sweeps) | Claude **sonnet** | **Codex** (`codex-mini`) |

**Within-Codex two-tier routing** (only when a task is routed to Codex):

| Target file glob | Codex model |
|---|---|
| `*/data/models/*.ts`, `*/data/enums/*.ts`, `*/data/schemas/*Schemas.ts`, `*/data/mappers/*.ts` | `codex-mini` |
| `*/data/infrastructure/*Service.ts`, `*/data/queries/*Queries.ts` | `gpt-5-codex` |
| Bulk lint/tsc fixes | `codex-mini` |

**Hard rules:**
1. React components (UI) always stay on Claude, even in `claude+codex+llm`. Codex has a documented weakness on React.
2. Integration tasks always stay on Claude opus. Multi-file reasoning is Claude's strength.
3. When dispatching Claude agents, always specify the `model` parameter explicitly.

**Dispatching a Codex task:**

For each task routed to Codex:

1. Determine the Codex model using the file-glob table above
2. Build the prompt by filling in the template at `skills/develop/codex-prompt.md`:
   - `{{TASK_DESCRIPTION}}` — the task text from the plan
   - `{{FILE_LIST}}` — the file list from the plan for this task
   - `{{ARCHITECTURE_DECISIONS}}` — relevant architecture decisions from the plan
   - `{{PATTERN_REFERENCES}}` — 1-2 existing files Codex should mirror (identify by searching the codebase for similar existing files)
   - `{{SHARED_STATE_CONTENTS}}` — current contents of `.shared-state.md`
3. Write the filled prompt to `$PROJECT_ROOT/.codex-prompt-<task-id>.txt`
4. Run:
   ```bash
   CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "codex-dispatch.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1)
   bash "$CRAFT_SCRIPTS/codex-dispatch.sh" "$PWD" "<task-id>" "<codex-model>" "$PWD/.codex-prompt-<task-id>.txt"
   ```
5. Read `$PROJECT_ROOT/.codex-output-<task-id>.json` and parse the `status` field
6. Route by status (see Error Handling below)
7. Delete the prompt and output files when done

**Error handling for Codex tasks:**

| Outcome | Action |
|---|---|
| exit 0, status `DONE` | verify `.shared-state.md` was updated (diff check), proceed |
| exit 0, status `DONE_WITH_CONCERNS` | log concerns from JSON, decide if a fix agent is needed, proceed |
| exit 0, status `NEEDS_CONTEXT` | provide missing context from plan/shared-state, re-dispatch the same task |
| exit 0, status `BLOCKED` | investigate blocker, fix root cause, re-dispatch |
| exit 0, output JSON missing or invalid | dispatch Claude **sonnet** reconcile agent to review Codex's file changes and update `.shared-state.md` |
| exit non-zero | dispatch Claude **sonnet** fallback agent for this specific task, note the fallback in `.shared-state.md` |

**Shared-state reconcile safeguard:** After every successful Codex run, diff `.shared-state.md` before and after the dispatch. If the file was not updated but Codex made file changes, dispatch a sonnet reconcile agent to inspect the changes and write the correct entries to shared state.
```

- [ ] **Step 2: Verify**

```bash
grep -c "Codex" /Users/alex/Projects/frontend/craft-skills/skills/develop/SKILL.md
```

Expected: at least 10 matches (multiple references in the new routing section).

- [ ] **Step 3: Commit**

```bash
cd /Users/alex/Projects/frontend/craft-skills
git add skills/develop/SKILL.md
git commit -m "feat(develop): route data-layer tasks to Codex when profile includes codex"
```

---

## Phase 6: `/craft-duo` wrapper

### Task 6.1: Create `skills/craft-duo/SKILL.md`

**Files:**
- Create: `skills/craft-duo/SKILL.md`

- [ ] **Step 1: Write the wrapper skill**

Write this exact content to `/Users/alex/Projects/frontend/craft-skills/skills/craft-duo/SKILL.md`:

````markdown
---
name: craft-duo
description: "Full design-first pipeline with Codex as a co-executor for data-layer tasks. Claude handles architecture and UI; Codex handles types, services, queries, schemas, enums, mappers, and bulk fixes. Use when you want cost relief via Codex without losing Claude's reasoning on UI and integration."
---

# Craft (duo variant: Claude + Codex)

Full design-first pipeline. Claude does brainstorming, architect planning, UI implementation, and integration wiring. Codex handles data-layer tasks via `codex exec`.

**Profile:** `claude+codex`

**Pipeline:** Brainstorm → Plan → Develop (hybrid executors) → Browser Test → Report (same phases as `/craft`)

## Requirements

- Codex CLI installed: `npm i -g @openai/codex`
- Codex authenticated: `codex login` (ChatGPT auth) or set `OPENAI_API_KEY`
- `AGENTS.md` present at project root (auto-generated from CLAUDE.md by `develop` pre-flight if missing or stale)

Does NOT require LM Studio.

## How this wrapper works

This wrapper writes the profile marker, then delegates to the canonical craft pipeline. The `develop` skill reads `.craft-profile` and routes data-layer tasks to Codex instead of Claude sonnet agents.

## Step 1: Write profile marker

```bash
echo -n "claude+codex" > .craft-profile
```

## Step 2: Follow the craft pipeline

Read `skills/craft/SKILL.md` from this plugin and follow every phase exactly as written. Profile gating in the craft and develop skills routes the relevant tasks to Codex.

The user input is: `$ARGUMENTS`

Pass the input through as if the user had invoked `/craft`.

## Expected behavior differences from `/craft`

- `develop` Step 0 runs a Codex CLI pre-flight check — fails loud if Codex is missing
- `develop` Step 2 routes data-layer tasks (`types`, `services`, `queries`, `schemas`, `enums`, `mappers`) to Codex
- `develop` Step 2 also routes bulk lint/tsc fix sweeps to Codex
- UI and integration tasks stay on Claude sonnet/opus
- LLM steps are skipped (no LM Studio dependency)

## Expected cost relief

Typical feature runs delegate ~30-40% of lines-of-code work to Codex, translating to roughly 15-20% overall cost relief per run. Varies significantly by feature shape: heavy data-layer features see more relief, UI-heavy features see less.
````

- [ ] **Step 2: Verify file**

```bash
head -5 /Users/alex/Projects/frontend/craft-skills/skills/craft-duo/SKILL.md
```

Expected: frontmatter with `name: craft-duo`.

- [ ] **Step 3: Commit**

```bash
cd /Users/alex/Projects/frontend/craft-skills
git add skills/craft-duo/
git commit -m "feat(craft-duo): add wrapper skill for claude+codex profile"
```

---

### Task 6.2: Smoke test `/craft-duo` on a tiny feature

This is a manual test in an adjacent frontend project. Record the result but do not commit.

- [ ] **Step 1: In an adjacent frontend project, invoke `/craft-duo` with a trivial data-layer feature**

Suggested prompt: "Add a new `Tag` entity with id, label, and colorHex fields. Include the types, a service with getAll/getById, and a React Query hook."

This is chosen because it's almost entirely data-layer work — high Codex share.

- [ ] **Step 2: Verify `.craft-profile` contains `claude+codex`**

```bash
cat <project-root>/.craft-profile
```

Expected: `claude+codex`

- [ ] **Step 3: Let the pipeline proceed through brainstorm + plan + develop**

- [ ] **Step 4: Verify during develop dispatch that Codex is invoked**

Watch the session for messages indicating `bash codex-dispatch.sh` calls. You should see at least 2-3 data-layer tasks dispatched to Codex (types, service, queries).

- [ ] **Step 5: Verify UI tasks (if any) still dispatched to Claude sonnet**

- [ ] **Step 6: Verify `AGENTS.md` was generated on the fly if missing**

```bash
ls -la <project-root>/AGENTS.md
head -20 <project-root>/AGENTS.md
```

Expected: file exists, starts with the Codex-specific constraints preamble.

- [ ] **Step 7: Verify the build passes**

After develop completes: `npm run lint && npx tsc --noEmit && npm run build` should exit 0.

- [ ] **Step 8: Inspect Codex-generated files for quality**

Open the generated files under `src/domain/tag/data/` and verify they match the project's existing patterns (DDD structure, named exports, no stray reformatting, matches existing service/queries style).

- [ ] **Step 9: Abort and clean up test feature**

Revert the test feature commits if you want to keep the project clean.

No commit for this task — smoke test only. Record issues and fix before proceeding to Phase 7.

---

## Phase 7: `/craft-squad` wrapper + adversarial review bonus

### Task 7.1: Create `skills/craft-squad/SKILL.md`

**Files:**
- Create: `skills/craft-squad/SKILL.md`

- [ ] **Step 1: Write the wrapper**

Write this exact content to `/Users/alex/Projects/frontend/craft-skills/skills/craft-squad/SKILL.md`:

````markdown
---
name: craft-squad
description: "Full design-first pipeline with all three AI agents: Claude (architect + UI + integration), Codex (data-layer + bulk fixes), and local LLM (LM Studio, for exploration + review). Power-user mode. Optionally runs Codex adversarial review if codex-plugin-cc is installed."
---

# Craft (squad variant: Claude + Codex + local LLM)

Full design-first pipeline with every AI component active. Combines `/craft-duo` (Codex for data layer) with `/craft-local` (LM Studio for review/exploration). Optionally enables a skeptical adversarial review from Codex via `codex-plugin-cc` if installed.

**Profile:** `claude+codex+llm`

**Pipeline:** Brainstorm → Plan → Develop (hybrid executors + LLM reviews + optional adversarial review) → Browser Test → Report

## Requirements

- Codex CLI installed: `npm i -g @openai/codex`
- Codex authenticated: `codex login` or `OPENAI_API_KEY`
- LM Studio running at `${LLM_URL:-http://127.0.0.1:1234}`
- `AGENTS.md` at project root (auto-generated)
- **Optional:** `codex-plugin-cc` installed in Claude Code — enables adversarial review bonus

## How this wrapper works

Writes the profile marker, then delegates to the canonical craft pipeline.

## Step 1: Write profile marker

```bash
echo -n "claude+codex+llm" > .craft-profile
```

## Step 2: Follow the craft pipeline

Read `skills/craft/SKILL.md` and follow every phase. All profile gates are satisfied: LLM steps run, Codex routing activates, and the develop skill checks for `codex-plugin-cc` to optionally run an adversarial review.

The user input is: `$ARGUMENTS`

## Expected behavior

- All LLM steps run (LM Studio required)
- All Codex routing runs (Codex CLI required)
- If `codex-plugin-cc` is installed, `develop` Step 3.5 invokes `/codex:adversarial-review` on the diff as a skeptical second-opinion review
- If `codex-plugin-cc` is NOT installed, the adversarial review step is silently skipped — no failure

## When to use

Use `/craft-squad` when:
- Stakes are high and you want every layer of review
- The feature is complex enough that a skeptical second opinion matters
- You have both LM Studio and Codex CLI available

For most day-to-day work, `/craft-duo` (no LLM) or `/craft` (no external deps) are usually enough.
````

- [ ] **Step 2: Verify file**

```bash
head -5 /Users/alex/Projects/frontend/craft-skills/skills/craft-squad/SKILL.md
```

Expected: frontmatter with `name: craft-squad`.

- [ ] **Step 3: Commit**

```bash
cd /Users/alex/Projects/frontend/craft-skills
git add skills/craft-squad/
git commit -m "feat(craft-squad): add wrapper skill for claude+codex+llm profile"
```

---

### Task 7.2: Add adversarial review bonus to `develop/SKILL.md` Step 3.5

**Files:**
- Modify: `skills/develop/SKILL.md`

- [ ] **Step 1: Add a new Step C.5 (adversarial review) in Step 3.5**

Find `**Step C — Act on findings:**` in Step 3.5 (it appears near the end of the Step 3.5 section). BEFORE it, insert:

```markdown
**Step C.5 — Codex adversarial review (optional, profile-gated):**

Runs only when profile includes `codex` AND the `codex-plugin-cc` plugin is installed. This provides a skeptical second-opinion code review from GPT-5-codex on Claude's implementation.

```bash
CRAFT_PROFILE=$(cat .craft-profile 2>/dev/null || echo "claude")
case "$CRAFT_PROFILE" in
  *codex*)
    # Check if codex-plugin-cc is installed (plugin has /codex:* commands)
    if [[ -d ~/.claude/plugins/cache/codex-plugin-cc ]] || [[ -d ~/.claude/plugins/codex-plugin-cc ]]; then
      echo "ADVERSARIAL_REVIEW_AVAILABLE"
    else
      echo "ADVERSARIAL_REVIEW_UNAVAILABLE_NO_PLUGIN"
    fi
    ;;
  *)
    echo "ADVERSARIAL_REVIEW_SKIPPED_BY_PROFILE"
    ;;
esac
```

If the check returned `ADVERSARIAL_REVIEW_AVAILABLE`, invoke the `codex-plugin-cc:adversarial-review` skill via the Skill tool. Pass the list of changed files from `.shared-state.md` as the review scope. When the skill returns, capture its findings and include them in the final Step C (Act on findings) triage alongside the graph and LLM review results.

If the plugin is not installed or the profile excludes codex, skip this step silently. This is a bonus, not a dependency — no error, no warning, no prompt to the user.

```

- [ ] **Step 2: Verify**

```bash
grep -n "Step C.5 — Codex adversarial" /Users/alex/Projects/frontend/craft-skills/skills/develop/SKILL.md
```

Expected: one match.

- [ ] **Step 3: Commit**

```bash
cd /Users/alex/Projects/frontend/craft-skills
git add skills/develop/SKILL.md
git commit -m "feat(develop): add optional Codex adversarial review via codex-plugin-cc"
```

---

### Task 7.3: Smoke test `/craft-squad`

Manual test. Requires both LM Studio and Codex.

- [ ] **Step 1: Start LM Studio**

- [ ] **Step 2: Verify Codex is available**

```bash
codex --version
```

Expected: version output (e.g., `codex-cli 0.118.0`).

- [ ] **Step 3: Invoke `/craft-squad` on a trivial feature in an adjacent frontend project**

Suggested prompt: "Add a `Tag` entity with types, service, and queries, plus a list page component that displays all tags."

This mixes data-layer (Codex) and UI (Claude sonnet) + integration (Claude opus), exercising the full routing.

- [ ] **Step 4: Verify `.craft-profile` is `claude+codex+llm`**

```bash
cat <project-root>/.craft-profile
```

- [ ] **Step 5: Verify LLM exploration runs (architect Step 0)**

Session logs show `LLM_AVAILABLE:...` and `llm-agent.sh` dispatches.

- [ ] **Step 6: Verify Codex routing runs (develop Step 2)**

Session logs show `codex-dispatch.sh` calls for data-layer tasks.

- [ ] **Step 7: Verify adversarial review runs if plugin is installed (develop Step 3.5)**

If `codex-plugin-cc` is installed, session logs show `ADVERSARIAL_REVIEW_AVAILABLE` and a subsequent `/codex:adversarial-review` invocation. If not installed, logs show `ADVERSARIAL_REVIEW_UNAVAILABLE_NO_PLUGIN` and the step is skipped.

- [ ] **Step 8: Verify build passes**

`npm run lint && npx tsc --noEmit && npm run build` should exit 0.

- [ ] **Step 9: Clean up test feature**

No commit for this task.

---

## Phase 8: Documentation + release

### Task 8.1: Update `bootstrap/SKILL.md` to list all four variants

**Files:**
- Modify: `skills/bootstrap/SKILL.md`

- [ ] **Step 1: Update the Implementation Skills table**

Open `skills/bootstrap/SKILL.md`. Find the `### Implementation Skills` table (the one that starts with `| Skill | Trigger Conditions |`). Replace the `craft-skills:craft` row with these four rows:

```markdown
| `craft-skills:craft` | Default craft pipeline (Claude only, no external deps). Use when requirements need deep exploration and you want the simplest, most reliable path. |
| `craft-skills:craft-duo` | Craft with Codex as a co-executor for data-layer tasks. Use when you want cost relief and have Codex CLI installed. |
| `craft-skills:craft-local` | Craft with LM Studio for supplementary LLM review. Use when you want deeper review and have LM Studio running. Preserves pre-1.1 craft behavior. |
| `craft-skills:craft-squad` | Craft with all three AIs: Claude + Codex + local LLM. Power-user mode. Optionally runs Codex adversarial review if codex-plugin-cc is installed. |
```

- [ ] **Step 2: Verify**

```bash
grep -c "craft-skills:craft" /Users/alex/Projects/frontend/craft-skills/skills/bootstrap/SKILL.md
```

Expected: at least 4 matches.

- [ ] **Step 3: Commit**

```bash
cd /Users/alex/Projects/frontend/craft-skills
git add skills/bootstrap/SKILL.md
git commit -m "docs(bootstrap): list all four craft variants in Implementation Skills"
```

---

### Task 8.2: Update the frontend-level `CLAUDE.md` workflow table

**Files:**
- Modify: `/Users/alex/Projects/frontend/.claude/CLAUDE.md`

- [ ] **Step 1: Update the craft-skills Workflow table**

Open `/Users/alex/Projects/frontend/.claude/CLAUDE.md`. Find the craft-skills Workflow table (starts with `| Skill | Purpose | When to Use |`). Replace the `craft` row with these four rows:

```markdown
| `craft` | Full pipeline: brainstorm → plan → develop → test (Claude only, no external deps) | Complex features, unclear requirements, simplest path |
| `craft-duo` | Craft with Codex as co-executor for data-layer tasks | Cost relief, requires Codex CLI |
| `craft-local` | Craft with LM Studio LLM reviews | Deeper review, requires LM Studio |
| `craft-squad` | Craft with Claude + Codex + LM Studio | Power-user mode, all three agents |
```

- [ ] **Step 2: Verify**

```bash
grep -c "craft-" /Users/alex/Projects/frontend/.claude/CLAUDE.md
```

Expected: at least 3 matches (craft-duo, craft-local, craft-squad).

- [ ] **Step 3: Commit (in the craft-skills repo, not the frontend parent)**

The frontend-level CLAUDE.md lives outside the craft-skills repo. This change is a separate commit in the parent directory:

```bash
cd /Users/alex/Projects/frontend
git add .claude/CLAUDE.md
git commit -m "docs: list craft-skills v1.1 variants in workflow table"
```

Note: this commit is in a different git repo than the rest of the plan. The craft-skills plugin commits and the frontend parent commit are independent.

---

### Task 8.3: Bump version in `plugin.json` and `marketplace.json`

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Bump `plugin.json` version**

Open `.claude-plugin/plugin.json`. Change:

```json
  "version": "1.0.26",
```

to:

```json
  "version": "1.1.0",
```

- [ ] **Step 2: Bump `marketplace.json` version (two places)**

Open `.claude-plugin/marketplace.json`. There are TWO version fields:

Change line ~8 `"version": "1.0.26"` to `"version": "1.1.0"`.
Change line ~15 `"version": "1.0.26"` to `"version": "1.1.0"`.

- [ ] **Step 3: Run the sync check to verify both files agree**

```bash
bash /Users/alex/Projects/frontend/craft-skills/scripts/sync-check.sh
```

Expected output: no version mismatch error.

- [ ] **Step 4: Verify JSON is still valid**

```bash
python3 -c "import json; json.load(open('/Users/alex/Projects/frontend/craft-skills/.claude-plugin/plugin.json')); json.load(open('/Users/alex/Projects/frontend/craft-skills/.claude-plugin/marketplace.json'))" && echo "VALID"
```

Expected: `VALID`

- [ ] **Step 5: Commit the version bump**

```bash
cd /Users/alex/Projects/frontend/craft-skills
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore: bump version to 1.1.0 for executor profiles feature"
```

---

### Task 8.4: Tag the release

- [ ] **Step 1: Create the tag**

```bash
cd /Users/alex/Projects/frontend/craft-skills
git tag -a v1.1.0 -m "v1.1.0 — Codex integration & executor profiles

New skills:
- /craft-duo: Claude + Codex hybrid for cost relief on data-layer tasks
- /craft-local: Claude + LM Studio (preserves pre-1.1 craft behavior)
- /craft-squad: All three AIs with optional adversarial review

Breaking:
- /craft no longer runs LLM exploration/review steps.
  Use /craft-local to restore the previous behavior.

Internal:
- AGENTS.md generated from CLAUDE.md via sync-agents-md.sh
- develop skill is profile-aware via .craft-profile marker file
- Codex dispatched via direct codex exec (not the codex-plugin-cc plugin)
- Two-tier Codex model routing (codex-mini vs gpt-5-codex)"
```

- [ ] **Step 2: Verify tag**

```bash
git tag -l v1.1.0
```

Expected output: `v1.1.0`

- [ ] **Step 3: Ask the user before pushing**

Tag creation is local; pushing to remote is the publish step. **Stop here and ask the user:** "Tag v1.1.0 created locally. Push to origin and publish the release?"

Do NOT push without explicit confirmation. Pushing is a visible, shared action.

---

## Self-Review Checklist (run after completing all tasks)

- [ ] All 4 wrapper skills exist: `craft`, `craft-duo`, `craft-local`, `craft-squad`
- [ ] `_craft-core/` directory has no `SKILL.md` (so it's not discovered as a user-facing skill)
- [ ] `.craft-profile` is written by all wrappers, read by `architect` and `develop`, cleaned up by `develop` Step 5
- [ ] All 4 LLM gate sites in `craft/SKILL.md` use the same `case "$CRAFT_PROFILE"` pattern
- [ ] `architect/SKILL.md` and `develop/SKILL.md` have their LLM calls gated
- [ ] `sync-agents-md.sh` is executable and passes `bash -n`
- [ ] `codex-status-schema.json` is valid JSON
- [ ] `codex-dispatch.sh` is executable and passes `bash -n`
- [ ] `develop/SKILL.md` has Step 0 pre-flight check for codex profiles
- [ ] `develop/SKILL.md` has Step 2 routing logic for Codex
- [ ] `develop/SKILL.md` has Step 3.5 Step C.5 for adversarial review
- [ ] `develop/SKILL.md` Step 5 cleans up `.craft-profile`
- [ ] `bootstrap/SKILL.md` lists all 4 variants
- [ ] `plugin.json` and `marketplace.json` are at `1.1.0` and agree
- [ ] Git log shows one commit per task (or logical group), all passing `git log --oneline`
- [ ] Tag `v1.1.0` exists locally
- [ ] At least one smoke test passed per variant (`/craft` no-LLM, `/craft-local` LLM, `/craft-duo` Codex, `/craft-squad` all three)

If any checklist item fails, go back to the relevant task and fix before proceeding.

---

## Notes for the implementer

- **Skill discovery:** Claude Code discovers skills by looking for `SKILL.md` files. The `_craft-core/` directory intentionally has no `SKILL.md`, so it won't be indexed as a skill. The `.md` files inside are reference documents that wrappers and other skills `Read` by path.
- **Wrapper delegation:** Wrappers instruct Claude to read and follow `craft/SKILL.md` as their "delegation" mechanism. This works because Claude loads `craft/SKILL.md` content into context when instructed. It's not a true function call — it's a documented handoff.
- **Profile gating pattern:** Every gate uses `CRAFT_PROFILE=$(cat .craft-profile 2>/dev/null || echo "claude")` followed by `case "$CRAFT_PROFILE" in *llm*) ... ;; *) ... ;; esac`. Keep this consistent across all sites so the pattern is greppable.
- **Codex prompt placeholders:** The `codex-prompt.md` template uses `{{...}}` placeholders. `develop` fills these in at dispatch time. This is a simple string substitution, not a templating engine — do not add Handlebars, Mustache, etc.
- **Error budget:** If Codex crashes or produces invalid output on a specific task during real use, the Claude fallback agent takes over for that task. This is by design — don't try to make Codex perfect, let the fallback handle edge cases.
- **Breaking change messaging:** Release notes and bootstrap docs must clearly say "`/craft` no longer runs LLM steps — use `/craft-local`." Users will hit this if they rely on LLM review.
- **Dispatching Claude and Codex in parallel:** Within a single phase (e.g., data layer), Codex tasks and Claude tasks can run in parallel — they're independent processes. This is the same parallelism rule that already applies to Claude agents.
