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

### 1.7 Write Spec

Save the validated design to `.claude/plans/specs/YYYY-MM-DD-{feature}-design.md`

### 1.8 UI/UX Review (conditional)

**Skip this step if the project does not have the `ui-ux-pro-max` skill available.**

If available, invoke the `ui-ux-pro-max` skill to review the spec's UI-related sections: component layouts, interaction patterns, step flows, form design, table design, error states, loading states, and accessibility.

Provide the skill with:
- The spec's component architecture and step-by-step UX flow
- The project's tech stack and UI framework context (from CLAUDE.md)
- Any design images or mockups referenced in the requirements

Incorporate actionable UI/UX improvements into the spec before proceeding. Skip purely aesthetic suggestions that conflict with the project's existing design system.

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
  bash "$CRAFT_SCRIPTS/llm-review.sh" <spec-file-path> "completeness, feasibility, API alignment, architecture compliance, internal consistency"
fi
```

**Review loop:** Since Gemma is local and free, run a review loop instead of a single pass:
1. Run `llm-review.sh` with the spec file
2. Triage findings — fix confirmed issues in the spec
3. Re-run `llm-review.sh` on the updated spec
4. Repeat until Gemma returns APPROVED or no actionable findings remain (max 4 rounds to prevent infinite loops)

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
    CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "llm-agent.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1) && bash "$CRAFT_SCRIPTS/llm-review.sh" <spec-file-path> "completeness, feasibility, API alignment, architecture compliance"
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
  bash "$CRAFT_SCRIPTS/llm-review.sh" <plan-file-path> "spec coverage, task ordering, completeness, risk areas"
fi
```

**Review loop:** Same as Step 1.10 — loop until Gemma approves or no actionable findings (max 4 rounds). After the loop, unload the model:

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
      CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "llm-agent.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1) && bash "$CRAFT_SCRIPTS/llm-review.sh" <plan-file-path> "spec coverage, task ordering, completeness, risk areas"
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

## Phase 4: Test

After a successful build, invoke `craft-skills:browser-test` with the spec/plan.

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
