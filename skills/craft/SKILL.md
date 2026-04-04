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

**Optional integrations:** The pipeline can leverage `craft-skills:llm-review` (local LLM) for supplementary reviews and `code-review-graph` for targeted file selection. See each skill/plugin for setup.

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

### 1.1 Explore Context

Use the **graph → LLM → manual** priority for exploration. Each layer builds on the previous — don't skip ahead.

**Layer 1 — Graph (instant, zero tokens):** If `code-review-graph` MCP is available, run these targeted queries:
- `semantic_search_nodes_tool` with feature-related keywords (e.g., "referral", "invite", "email") — finds existing code related to the feature
- `query_graph_tool` with `file_summary` on suspect domain dirs — maps existing structure
- `list_communities_tool` — shows domain clusters and their relationships

**Do NOT use `get_architecture_overview_tool`** — it returns the entire graph (can exceed 300K chars on large projects). Use targeted queries instead.

**Layer 2 — LLM agent (background, saves tokens):** Check availability: `bash scripts/llm-agent.sh "" 2>/dev/null` — if NOT `LLM_UNAVAILABLE`, run a **focused** task in the **background**:

```
bash scripts/llm-agent.sh "Investigate [2-3 specific domain paths from graph results] for a [feature] feature. Check: 1) What types/services exist in these domains 2) How forms and validation are set up 3) Any related API endpoints. Give a structured summary." <project-root>
```

**Scoping rule:** Never ask the agent to "explore the whole project." Always give it specific directories or files from graph results. Broad prompts cause the agent to hit max iterations and waste time.

**Layer 3 — Claude reads (minimal):** While graph queries run and LLM processes in background, Claude reads ONLY:
- The project's CLAUDE.md (both parent and project-level)
- Recent git commits for context (`git log --oneline -10`)

**DO NOT** dispatch explore agents, read domain source files, or run Grep/Glob searches while waiting for the LLM agent. When it finishes, use its summary as the exploration base.

**Fallback — if LLM is unavailable or fails:** Use graph query results + targeted file reads on the specific files the graph identified. If graph is also unavailable, dispatch **sonnet** agents for exploration.

### 1.2 Scope Assessment

Before detailed questions, assess scope:
- If the request describes multiple independent subsystems, flag this immediately
- Help decompose into sub-projects if needed — each gets its own spec → plan → implementation cycle

### 1.3 DDD-Specific Analysis

Before asking user questions, investigate (use the agent's exploration results if available):
- **Which domain(s)?** Where does this feature belong?
- **Cross-domain implications?** Will this need shared hooks or types?
- **Existing components?** What can be reused from `src/domain/shared/` and `src/domain/forms/fields/`?
- **Backend alignment?** Do API endpoints exist or need creation?

### 1.4 Clarifying Questions

Ask questions one at a time to refine the idea:
- Prefer multiple choice when possible
- Focus on: purpose, constraints, success criteria, business rules
- DDD questions: domain placement, boundary implications, data ownership
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
- The project's tech stack context (e.g., DaisyUI, Tailwind, React)
- Any design images or mockups referenced in the requirements

Incorporate actionable UI/UX improvements into the spec before proceeding. Skip purely aesthetic suggestions that conflict with the project's existing design system.

### 1.9 Spec Self-Review

Review the spec with fresh eyes:
1. **Placeholder scan:** Any "TBD", "TODO", incomplete sections? Fix them.
2. **Internal consistency:** Do sections contradict each other?
3. **Scope check:** Focused enough for a single plan?
4. **Ambiguity check:** Could any requirement be interpreted two ways? Pick one, make it explicit.

### 1.10 Agent Spec Review

Spawn a fresh agent (**code-reviewer type, opus model**) to review the spec with zero prior context. The agent has no knowledge of the brainstorming conversation, so it reviews the spec purely on its own merits against the codebase and backend contracts.

Provide the agent with:
- The spec file path
- The project's CLAUDE.md files (parent + project-level)
- Pointers to relevant backend contract files (if applicable)
- A clear review mandate: backend alignment, existing codebase patterns, completeness, feasibility, file structure

The agent should categorize findings as: Critical / Important / Minor / Suggestions.

**Why opus:** Spec review is a critical gate — a missed issue here cascades through the entire implementation. This is not the place to save on model cost.

**Parallel local LLM review (optional):** If `craft-skills:llm-review` skill is available, invoke it on the spec file **in parallel** with the opus agent. Free supplementary review — may catch issues the opus agent missed.

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

Spawn a fresh agent (**code-reviewer type, sonnet model**) to review the plan with zero prior context.

Provide the agent with:
- The plan file path
- The spec file path
- The project's CLAUDE.md files
- A clear review mandate: spec coverage, codebase alignment (read the actual files being modified), task ordering, completeness, risk areas

The agent should categorize findings as: Critical / Important / Minor / Suggestions.

**Why sonnet:** The plan is a structured breakdown of an already-reviewed spec. The review checks coverage and ordering — systematic work that doesn't require opus-level reasoning.

**Parallel local LLM review (optional):** If `craft-skills:llm-review` skill is available, invoke it on the plan file **in parallel** with the sonnet agent. Free supplementary review — does not block the pipeline.

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
