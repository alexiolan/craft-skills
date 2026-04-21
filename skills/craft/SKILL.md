---
name: craft
description: "Use when starting a new feature that needs thorough design exploration. This is the most comprehensive workflow: collaborative brainstorming with the user, then planning, then parallel agent development, then browser testing. Use for complex features, unclear requirements, or when the user wants to explore approaches before committing."
---

# Craft

The full design-first development pipeline. Collaborative design exploration with the user, then implementation, then browser testing.

**Pipeline:** Brainstorm → Plan → Develop → Browser Test → Report

## Model Selection Strategy

This pipeline uses a three-tier model strategy to optimize speed, cost, and quality:

| Tier | Model | Used For | Why |
|---|---|---|---|
| **Premium** | opus | Brainstorming (main conversation), spec writing, spec review agent, integration tasks | Deep reasoning, creative exploration, critical analysis |
| **Balanced** | sonnet | Context exploration agents, plan review agent, data layer + UI implementation agents | Good balance — doesn't need opus-level reasoning |
| **Fast** | haiku | Browser test agents | Fast and cheap — UI clicks and text verification |

When dispatching Claude agents, always specify the `model` parameter explicitly. The main conversation model is controlled by the user — these guidelines apply only to dispatched agents.

<HARD-GATE>
Do NOT write any implementation code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it. This applies to EVERY feature regardless of perceived simplicity.
</HARD-GATE>

## Input

The user input is: `$ARGUMENTS`

### Input Type Detection

1. **Prompt File Number** (e.g., `01`, `07`):
   - Read from `.claude/prompts/{number}*.md`

2. **Direct Prompt Text** (e.g., `Add a pricing modal to the property list`):
   - Use it directly as the feature description

3. **Empty Input**:
   - Ask the user to provide either a prompt file number or direct requirements

## Phase 1: Brainstorm

### 1.0 Set Executor Profile

First action in the pipeline. Write the profile marker so later steps can gate behavior correctly.

```bash
echo -n "claude" > .craft-profile
```

This is the base `/craft` profile — Claude only, no Codex, no local LLM. LLM-related steps in this file are gated on this profile and will be skipped. Users who want LLM-assisted review should invoke `/craft-local` instead.

### 1.1 Explore Context

Run graph tools and LLM bash directly in this conversation — no dedicated agents for these.

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

**Step 2 — Start LLM exploration in background (if available AND profile includes llm):**

Run only if Step 1 returned `LLM_AVAILABLE` (which only happens when the profile includes `llm`). If Step 1 returned `LLM_SKIPPED_BY_PROFILE` or `LLM_UNAVAILABLE`, skip this step.

If eligible, run with Bash tool (`run_in_background: true`, timeout 300000ms). Self-contained profile check for safety:

```bash
CRAFT_PROFILE=$(cat .craft-profile 2>/dev/null || echo "claude")
case "$CRAFT_PROFILE" in
  *llm*)
    CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "llm-agent.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1)
    bash "$CRAFT_SCRIPTS/llm-agent.sh" "Investigate [2-3 domain paths relevant to the feature] for a [feature] feature. Check: 1) What types/services exist in these domains 2) How forms and validation are set up 3) Any related API endpoints. Give a structured summary." <project-root>
    ;;
  *)
    echo "LLM_EXPLORATION_SKIPPED_BY_PROFILE"
    ;;
esac
```

Do NOT unload — more LLM steps follow (spec review 1.10, plan review 2.4).

**Step 3 — Run graph exploration (while LLM processes in background):**

Load graph MCP tools via ToolSearch (search for "code-review-graph"), then run:
1. `build_or_update_graph_tool` — ensure graph is fresh
2. `semantic_search_nodes_tool` — search with feature keywords (try 2-3 variations if few results)
3. For relevant domain directories: `query_graph_tool` with pattern `file_summary`
4. For key files: `query_graph_tool` with `imports_of` and `importers_of`

**NEVER** use `get_architecture_overview_tool`, `list_communities_tool`, or `detect_changes_tool` — they return 90-300K+ chars.

**Step 4 — Read project context** (in parallel with graph queries):
- The project's CLAUDE.md (both parent and project-level)
- Recent git commits (`git log --oneline -10`)

**Scoping rule:** Never ask to "explore the whole project." Always scope to specific directories or files.

**Fallback — if both LLM and graph are unavailable:** Dispatch **sonnet** agents for exploration.

### 1.2 Scope Assessment

Before detailed questions, assess scope:
- If the request describes multiple independent subsystems, flag this immediately
- Help decompose into sub-projects if needed — each gets its own spec → plan → implementation cycle

### 1.3 Architecture Analysis

Before asking user questions, investigate (use the exploration results):
- **Which module(s)?** Where does this feature belong in the project structure?
- **Cross-module implications?** Will this need shared utilities or types?
- **Existing components?** What can be reused from the project's shared/common modules?
- **API alignment?** Do API endpoints exist or need creation?

### 1.4 Clarifying Questions

Ask questions one at a time to refine the idea:
- Prefer multiple choice when possible
- Focus on: purpose, constraints, success criteria, business rules
- Architecture questions: module placement, boundary implications, data ownership
- Do NOT combine multiple questions in one message

### 1.5 Propose Approaches

Once you understand the requirement:
- Propose 2-3 different approaches with trade-offs
- Lead with your recommendation and explain why
- Include: architecture differences, complexity, reuse potential

### 1.6 Present Design

Present the design in sections, scaled to complexity:
- Ask after each section whether it looks right
- Cover: architecture, components, data flow, error handling
- Be ready to revise if something doesn't make sense

### 1.6.5 Reuse-Index Gate (conditional, non-blocking)

Before writing the spec (which now requires a Prior-Art Scan table — see below), ensure the project's reuse contract exists.

```bash
if [ ! -f .claude/reuse-index.md ]; then
  echo "REUSE_INDEX_MISSING"
else
  echo "REUSE_INDEX_PRESENT"
fi
```

- `REUSE_INDEX_PRESENT` → continue to 1.7.
- `REUSE_INDEX_MISSING` → invoke `craft-skills:reuse-index` via the Skill tool. Non-blocking, one-time-per-project cost. Mirrors the `aesthetic-direction` gate at 1.8a. Continue once the skill returns (or is skipped).

### 1.7 Write Spec

Save the validated design to `.claude/plans/specs/YYYY-MM-DD-{feature}-design.md`

**Prior-Art Scan (MANDATORY section in the spec):**
Before saving, include a "Prior-Art Scan" table in the spec for every new concept (type, enum, helper, util, hook, component, shared constant) it introduces. Each row records: the concept, where you searched (graph queries, globs, greps), whether prior art exists, and the decision (reuse / extend / justify new). If `.claude/reuse-index.md` exists at the project root, consult it before searching and cite matching entries in the row. Common false-negative traps to always search for: date formatting, HTTP clients, toast/notification primitives, icon wrappers, drawer/modal/accordion primitives, enum→label maps, relative-time helpers, string normalizers, pluralization.

### 1.8 Design-Layer Gate (conditional, deterministic)

Replaces the earlier ambient "UI/UX Review." Fires only when the spec includes UI work, and invokes skills deterministically with transparent gating.

**Skip this step unless the spec introduces UI** — new components, pages, forms, tables, modals, or modifications to any `.tsx`/`.vue`/`.svelte` file. For backend-only specs, jump to 1.9.

**1.8a — Ensure aesthetic direction exists:**

```bash
if [ ! -f .claude/aesthetic-direction.md ]; then
  echo "AESTHETIC_MISSING"
else
  echo "AESTHETIC_PRESENT"
fi
```

If `AESTHETIC_MISSING`, invoke `craft-skills:aesthetic-direction` via the Skill tool. The skill generates `.claude/aesthetic-direction.md` non-blockingly (user can refine later). One-time cost per project.

**1.8b — Generate UX brief:**

Invoke `craft-skills:ux-brief` via the Skill tool with the spec path as argument. It will:
- Parse complexity tags (explicit from `complexity:` frontmatter, or inferred from keywords like "comparison", "dashboard", "complex-form", "data-dense")
- Run solo mode (`frontend-design` only) for simple UI or combined mode (`frontend-design` + `ui-ux-pro-max`) for complex UI
- Write `.claude/plans/{feature-dir}/ux-brief.md` with diagnosis, prioritized patches, success criteria
- Return path + mode + availability summary

**1.8c — Incorporate brief into spec:**

Read the returned `ux-brief.md`. Fold its key decisions into the spec:
- Copy the "Success criteria" section into the spec's acceptance criteria
- Reference the brief's P0 patches in the spec's UI component section — each becomes a spec requirement
- Preserve the brief's "Layout-parity guards" — they are hard constraints downstream impl must honor

**Fallback:** if `ux-brief` skill cannot run (e.g. `frontend-design` skill not installed), continue without it. Add a note to the spec: `> UX brief not generated (skill unavailable). Spec proceeds without design-layer contract.`

### 1.9 Spec Self-Review

Review the spec with fresh eyes:
1. **Placeholder scan:** Any "TBD", "TODO", incomplete sections? Fix them.
2. **Internal consistency:** Do sections contradict each other?
3. **Scope check:** Focused enough for a single plan?
4. **Ambiguity check:** Could any requirement be interpreted two ways? Pick one, make it explicit.

### 1.10 Agent Spec Review

**Profile gate — `claude+ace`:**

When `CRAFT_PROFILE` is `claude+ace`, SKIP the opus agent spec review below. Instead, run Gemma in a review loop:

```bash
CRAFT_PROFILE=$(cat .craft-profile 2>/dev/null || echo "claude")
if [ "$CRAFT_PROFILE" = "claude+ace" ]; then
  CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "llm-review.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1)
  bash "$CRAFT_SCRIPTS/llm-review.sh" <spec-file-path> "completeness, feasibility, API alignment, architecture compliance, internal consistency, security/safety, reuse/duplication (any new util/type/helper that duplicates an existing shared implementation)"
fi
```

**Review loop:** Since Gemma is local and free, run a review loop instead of a single pass:
1. Run `llm-review.sh` with the spec file
2. Triage findings — fix confirmed issues in the spec
3. Re-run `llm-review.sh` on the updated spec
4. Stop when **either** of these is true (whichever comes first):
   - **2 consecutive clean rounds** ("No confirmed issues found" twice in a row) — high confidence the spec is stable
   - **4 fix rounds total** — diminishing-returns ceiling, prevents infinite loops on wording nits
5. If Gemma flips on the same wording across rounds (clean → finding → clean for the same item), stop after the second oscillation and treat the spec as approved.

**Rationale:** The older "max 4 rounds" guidance was too aggressive — empirically Gemma often reopens spec wording details after one clean pass but stabilizes by the second. Going beyond ~6 rounds total has near-zero ROI. Adding `security/safety` to the review prompt catches SSRF / injection / DoS issues in the spec phase, where they're cheapest to fix.

After the loop completes, skip directly to Step 1.11 (user review). Do NOT dispatch the opus agent or the parallel LLM review — Gemma handles both roles.

For all other profiles, proceed with the existing behavior below.

Spawn a fresh agent (**code-reviewer type, opus model**) to review the spec with zero prior context. The agent has no knowledge of the brainstorming conversation, so it reviews the spec purely on its own merits against the codebase and backend contracts.

Provide the agent with:
- The spec file path
- The project's CLAUDE.md files (parent + project-level)
- Pointers to relevant backend contract files (if applicable)
- A clear review mandate: backend alignment, existing codebase patterns, completeness, feasibility, file structure

The agent should categorize findings as: Critical / Important / Minor / Suggestions.

**Why opus:** Spec review is a critical gate — a missed issue here cascades through the entire implementation. This is not the place to save on model cost.

**Parallel local LLM review (profile-gated):**

Only runs when profile includes `llm`. Run with Bash tool (`run_in_background: true`, timeout 300000ms) in parallel with the opus agent:

```bash
CRAFT_PROFILE=$(cat .craft-profile 2>/dev/null || echo "claude")
case "$CRAFT_PROFILE" in
  *llm*)
    CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "llm-agent.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1) && bash "$CRAFT_SCRIPTS/llm-review.sh" <spec-file-path> "completeness, feasibility, API alignment, architecture compliance, security/safety, reuse/duplication (any new util/type/helper that duplicates an existing shared implementation)"
    ;;
  *)
    echo "LLM_SPEC_REVIEW_SKIPPED"
    ;;
esac
```

Do NOT unload — more LLM steps may follow.

After receiving the review(s):
1. **Triage findings** — not everything flagged is actually wrong (the reviewer lacks conversation context). Evaluate each finding against what was discussed with the user.
2. **Fix confirmed issues** in the spec.
3. **Ask the user** about any findings that require a product decision.

### 1.11 User Reviews Spec

> "Spec written to `<path>`. Please review and let me know if you want changes before we plan implementation."

Wait for approval. If changes requested, revise and re-review.

## Phase 2: Plan

### 2.1 Map File Structure

Before defining tasks, map out which files will be created or modified:
- Design units with clear boundaries and well-defined interfaces
- Each file should have one clear responsibility
- Follow existing codebase patterns

### 2.2 Create Implementation Tasks

Break into bite-sized tasks (2-5 minutes each):
- Exact file paths
- Complete code — no placeholders
- Specify parallel vs sequential execution
- Data layer first → UI components (parallel) → integration last

### 2.3 Plan Self-Review

1. **Spec coverage:** Does every requirement have a task?
2. **Placeholder scan:** Any vague steps?
3. **Type consistency:** Names match across tasks?

### 2.4 Agent Plan Review

**Profile gate — `claude+ace`:**

When `CRAFT_PROFILE` is `claude+ace`, SKIP the sonnet agent plan review below. Instead, run Gemma in a review loop:

```bash
CRAFT_PROFILE=$(cat .craft-profile 2>/dev/null || echo "claude")
if [ "$CRAFT_PROFILE" = "claude+ace" ]; then
  CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "llm-review.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1)
  bash "$CRAFT_SCRIPTS/llm-review.sh" <plan-file-path> "spec coverage, task ordering, completeness, risk areas, security/safety, reuse/duplication (flag any new util/type/helper the plan creates that duplicates an existing shared implementation)"
fi
```

**Review loop:** Same termination rules as Step 1.10 — stop when **either** 2 consecutive clean rounds occur OR 4 fix rounds have happened, whichever comes first. Treat oscillation on the same wording as approval. After the loop, unload the model:

```bash
bash "$CRAFT_SCRIPTS/llm-unload.sh"
```

After the loop completes, skip directly to Step 2.5 (save and approve). Do NOT dispatch the sonnet agent or the parallel LLM review.

For all other profiles, proceed with the existing behavior below.

Spawn a fresh agent (**code-reviewer type, sonnet model**) to review the plan with zero prior context.

Provide the agent with:
- The plan file path
- The spec file path
- The project's CLAUDE.md files
- A clear review mandate: spec coverage, codebase alignment (read the actual files being modified), task ordering, completeness, risk areas

The agent should categorize findings as: Critical / Important / Minor / Suggestions.

**Why sonnet:** The plan is a structured breakdown of an already-reviewed spec. The review checks coverage and ordering — systematic work that doesn't require opus-level reasoning.

**Parallel supplementary reviews:**

- **LLM review (profile-gated):** Run with Bash tool (`run_in_background: true`, timeout 300000ms):
  ```bash
  CRAFT_PROFILE=$(cat .craft-profile 2>/dev/null || echo "claude")
  case "$CRAFT_PROFILE" in
    *llm*)
      CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "llm-agent.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1) && bash "$CRAFT_SCRIPTS/llm-review.sh" <plan-file-path> "spec coverage, task ordering, completeness, risk areas, security/safety, reuse/duplication (flag any new util/type/helper the plan creates that duplicates an existing shared implementation)"
      bash "$CRAFT_SCRIPTS/llm-unload.sh"
      ;;
    *)
      echo "LLM_PLAN_REVIEW_SKIPPED"
      ;;
  esac
  ```
- **Graph impact check:** Run `get_impact_radius_tool` on each file from the plan. Catches unintended side effects from modifying shared files. Runs in all profiles (graph is not gated).

After receiving the review(s):
1. **Triage findings** — evaluate each against conversation context and actual codebase.
2. **Fix confirmed issues** in the plan.
3. **Ask the user** about any findings that require a product decision.

### 2.5 Save and Approve Plan

Save to `.claude/plans/YYYY-MM-DD-{feature}.md`

Present summary and wait for user approval.

## Phase 3: Develop

Invoke `craft-skills:develop` with the approved plan.

## Phase 3.5: Design Review (conditional)

Runs only when UI files were created/modified (check `.shared-state.md` "Created / Modified Files" for `.tsx`/`.vue`/`.svelte` extensions).

If UI files are present, invoke `craft-skills:design-review`. It:
- Starts the dev server (if not running)
- Captures screenshots of affected routes at desktop + mobile viewports
- Dispatches a Haiku-vision agent to compare screenshots against `.claude/aesthetic-direction.md` and the feature's `ux-brief.md` success criteria
- Writes `.claude/plans/{feature-dir}/design-review.md` with PASS / MINOR_ISSUES / MAJOR_ISSUES verdict

Based on the verdict:
- **PASS** → proceed to Phase 4
- **MINOR_ISSUES** → the skill automatically dispatches a sonnet fix agent and re-runs review; continue when clean
- **MAJOR_ISSUES** → STOP, report findings to user, await guidance before Phase 4

Skip this phase silently if no UI files changed OR `.claude/aesthetic-direction.md` does not exist.

## Phase 4: Test

After a successful build AND design-review has passed (if applicable), invoke `craft-skills:browser-test` with the spec/plan.

## Phase 5: Report

Summarize the full journey:
- Design decisions made during brainstorming
- Files created/modified during implementation
- Test results
- Any open items or future considerations

## Key Principles

- **One question at a time** — don't overwhelm
- **YAGNI ruthlessly** — remove unnecessary features
- **Explore alternatives** — always propose 2-3 approaches
- **Incremental validation** — get approval before moving on
