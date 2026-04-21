---
name: architect
description: "Use when the user needs to plan and architect a new feature before implementation begins. This includes analyzing requirements, asking clarifying questions, and creating a detailed implementation plan aligned with the project's architecture. Invoke BEFORE any coding work starts."
---

# Architect

Analyze requirements and create a detailed implementation plan. No code is written — only planning.

## Input

The user input is: `$ARGUMENTS`

### Input Type Detection

1. **Prompt File Number** (e.g., `01`, `07`):
   - Read from `.claude/prompts/{number}*.md`
   - Example: `01` → reads `.claude/prompts/01-initial-structure.md`

2. **Direct Prompt Text** (e.g., `Add a logout button to the navbar`):
   - Use it directly as the feature requirements

3. **Empty Input**:
   - Ask the user to provide either a prompt file number (list available from `.claude/prompts/`) or direct requirements

### Error Handling

- **File not found**: Report error and list available prompt files
- **Multiple matches**: List all and ask user to specify
- **Empty file**: Report and ask for requirements

## Process

### Step 0: Pre-Exploration (save architect tokens)

Before dispatching the architect agent, gather context directly — no dedicated agents for graph or LLM.

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

Skip if Step 1 returned `LLM_SKIPPED_BY_PROFILE` or `LLM_UNAVAILABLE`. Otherwise run with Bash tool (`run_in_background: true`, timeout 300000ms). Self-contained profile check:

```bash
CRAFT_PROFILE=$(cat .craft-profile 2>/dev/null || echo "claude")
case "$CRAFT_PROFILE" in
  *llm*)
    CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "llm-agent.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1)
    bash "$CRAFT_SCRIPTS/llm-agent.sh" "Investigate [2-3 domain paths] for a [feature] feature. Check: types, services, components, patterns, API endpoints. Structured summary." <project-root>
    ;;
  *)
    echo "LLM_EXPLORATION_SKIPPED_BY_PROFILE"
    ;;
esac
```

When standalone, unload after only if LLM was actually loaded:

```bash
CRAFT_PROFILE=$(cat .craft-profile 2>/dev/null || echo "claude")
case "$CRAFT_PROFILE" in
  *llm*)
    CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "llm-unload.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1)
    bash "$CRAFT_SCRIPTS/llm-unload.sh"
    ;;
esac
```

When part of craft pipeline, skip unloading (the parent craft skill handles it in Step 2.4).

**Step 3 — Run graph exploration (while LLM processes):**

Load graph MCP tools via ToolSearch (search for "code-review-graph"), then run:
1. `build_or_update_graph_tool` — ensure graph is fresh
2. `semantic_search_nodes_tool` — search with feature keywords (2-3 variations)
3. For relevant domains: `query_graph_tool` with `file_summary`
4. For key files: `query_graph_tool` with `imports_of` and `importers_of`

**NEVER** use `get_architecture_overview_tool`, `list_communities_tool`, or `detect_changes_tool`.

**Scoping rule:** Never ask to "explore the whole codebase." Always scope to specific directories or files.

Wait for both agents to complete. Pass their findings to the architect agent in Step 1.

### Step 1: Dispatch Architect Agent

Dispatch an **implementation-architect** agent (**opus model**) using the Agent tool. Read the agent prompt template from the `architect-prompt.md` file in this skill's directory, then append the requirements to it.

**Include in the agent prompt:**
- The requirements
- LLM agent findings from Step 0 (if available) — prefix with "Codebase exploration summary (from a prior investigation, trust but verify specific claims):"
- Graph agent findings from Step 0 (if available) — prefix with "Graph exploration summary (structural analysis — domains, files, dependencies):"

The agent should:
1. Read the project's CLAUDE.md thoroughly
2. Use the pre-exploration findings as a starting point — only read additional files if the findings are insufficient or need verification
3. Check the backend API (if an additional working directory exists) for endpoint alignment
4. Ask clarifying questions if requirements are ambiguous
5. Create a detailed implementation plan

Relay any clarification questions the architect raises to the user. Wait for answers before proceeding.

### Step 1.5: Design-Layer Gate (conditional, deterministic)

This step replaces the older ambient "UI/UX plan review." Instead of opportunistic skill auto-triggering, the design-layer runs explicitly and deterministically — only when the plan touches UI, with transparent gating on solo vs combined mode.

**1.5a — Does the plan touch UI?**

Inspect the plan's file list. If any target file matches `**/*.{tsx,vue,svelte,jsx}` or lives under `feature/`, `ui/`, `components/`, `pages/`, `src/app/**`, proceed. Otherwise skip the entire design-layer and jump to Step 2.

**1.5b — Ensure aesthetic direction exists:**

```bash
if [ ! -f .claude/aesthetic-direction.md ]; then
  echo "AESTHETIC_MISSING"
else
  echo "AESTHETIC_PRESENT"
fi
```

- `AESTHETIC_PRESENT` → continue to 1.5c
- `AESTHETIC_MISSING` → invoke `craft-skills:aesthetic-direction` via the Skill tool. It generates `.claude/aesthetic-direction.md` non-blockingly and returns. This is a one-time-per-project cost.

**1.5c — Generate UX brief:**

Invoke `craft-skills:ux-brief` via the Skill tool with the spec/plan path as argument.

The `ux-brief` skill will:
1. Parse complexity tags (explicit from spec frontmatter, or inferred from keywords)
2. Invoke `frontend-design` (solo) or `frontend-design + ui-ux-pro-max` (combined) based on complexity
3. Write `.claude/plans/{feature-dir}/ux-brief.md` with diagnosis + prioritized patches + success criteria
4. Return the brief path and mode used

**1.5d — Integrate brief into plan:**

Read the returned `ux-brief.md`. For each P0/P1 patch in the brief:
- Add corresponding tasks to the plan
- Reference the brief's "Touch" and "Tokens to use" fields in each task
- Preserve the brief's "Layout-parity guard" clauses — downstream agents must honor them
- Include the brief's "Success criteria" in the plan's acceptance criteria section

If the brief's priorities contradict the plan's task ordering, favor the brief — it has the UX reasoning.

**Fallback:** if `ux-brief` skill is unavailable (e.g. `frontend-design` not installed), continue without a brief. Add a note to the plan: `> UX brief not generated (skill unavailable). UI implementation proceeds against CLAUDE.md conventions only.`

### Step 2: Plan Review

Review the implementation plan and verify:

- Alignment with requirements
- **Prior-Art Scan table is present and filled** — every new type/enum/helper/util/hook/component introduced by the plan has a row documenting where the agent searched and what was found. A plan without this table, or with a row that admits prior art exists but the plan still specifies a new copy, must be rejected and sent back. This is the single biggest defense against duplication.
- No duplication of existing codebase functionality (reuse > recreate)
- Follows patterns documented in CLAUDE.md
- Optimal approach with best practices
- Existing components and utilities are reused where possible
- If Step 1.5 produced a ux-brief, the plan's UI tasks reflect the brief's P0/P1 patches and reference its success criteria

Ask the user for approval:
- If approved → save plan and report its path
- If changes requested → send back to architect for revision

### Step 3: Save Plan

Save the approved plan to `.claude/plans/YYYY-MM-DD-{feature-name}.md` and report the path.

The plan is now ready for `craft-skills:develop` or `craft-skills:finalize`.
