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

### Step 2: Plan Review

Review the implementation plan and verify:

- Alignment with requirements
- No duplication of existing codebase functionality (reuse > recreate)
- Follows patterns documented in CLAUDE.md
- Optimal approach with best practices
- Existing components and utilities are reused where possible

**UI/UX plan review (conditional):** If the `ui-ux-pro-max` skill is available AND the plan includes UI components (pages, forms, modals, tables), invoke it to review the plan's UI architecture: component hierarchy, interaction flows, loading/error states, and accessibility. Incorporate actionable suggestions into the plan. Skip if the project has no UI layer or the skill is not installed.

Ask the user for approval:
- If approved → save plan and report its path
- If changes requested → send back to architect for revision

### Step 3: Save Plan

Save the approved plan to `.claude/plans/YYYY-MM-DD-{feature-name}.md` and report the path.

The plan is now ready for `craft-skills:develop` or `craft-skills:finalize`.
