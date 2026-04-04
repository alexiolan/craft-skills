---
name: architect
description: "Use when the user needs to plan and architect a new feature before implementation begins. This includes analyzing requirements, asking clarifying questions, and creating a detailed implementation plan aligned with DDD architecture. Invoke BEFORE any coding work starts."
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

Before dispatching the architect agent, gather context so the agent doesn't need to read files itself. Follow the **graph → LLM** order — graph scopes what the LLM investigates.

**First — Graph (if code-review-graph available):** Run `build_or_update_graph_tool`, then `semantic_search_nodes_tool` with feature-related keywords. This identifies which domains, files, and patterns are relevant — takes seconds, costs zero tokens.

**Then — LLM agent (MANDATORY):** Check availability: `curl -s --max-time 2 ${LLM_URL:-http://127.0.0.1:1234} > /dev/null 2>&1 && echo "LLM_AVAILABLE" || echo "LLM_UNAVAILABLE"`

If available, dispatch with **specific paths from graph results** (not a broad "explore" prompt):
```
CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "llm-agent.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1)
bash "$CRAFT_SCRIPTS/llm-agent.sh" "Investigate [2-3 specific domain paths or files from graph results] for a [feature] feature. Check: 1) Existing types, services, and components 2) Patterns and conventions used 3) API endpoints if they exist. Give a structured summary." <project-root>
```

If the scripts path was provided at session start (bootstrap context), use that instead of the `find` command.

**Scoping rule:** Never ask the agent to "explore the whole codebase." Always scope to specific directories or files from graph results. Broad prompts cause max-iteration failures.

Wait for the LLM agent to complete. Pass its findings + graph results to the architect agent in Step 1 — this saves thousands of tokens by preventing the agent from re-reading the same files.

### Step 1: Dispatch Architect Agent

Dispatch an **implementation-architect** agent (**opus model**) using the Agent tool. Read the agent prompt template from the `architect-prompt.md` file in this skill's directory, then append the requirements to it.

**Include in the agent prompt:**
- The requirements
- LLM agent findings from Step 0 (if available) — prefix with "Codebase exploration summary (from a prior investigation, trust but verify specific claims):"
- Graph query results from Step 0 (if available)

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
- Form fields use existing components where possible

Ask the user for approval:
- If approved → save plan and report its path
- If changes requested → send back to architect for revision

### Step 3: Save Plan

Save the approved plan to `.claude/plans/YYYY-MM-DD-{feature-name}.md` and report the path.

The plan is now ready for `craft-skills:develop` or `craft-skills:finalize`.
