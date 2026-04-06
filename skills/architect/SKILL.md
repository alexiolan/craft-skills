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

Before dispatching the architect agent, gather context. Dispatch both agents in **parallel**.

<HARD-GATE>
**DO NOT** load `craft-skills:graph-explore` or `craft-skills:llm-review` via the Skill tool — they are agent prompt templates, not main-conversation skills.
**DO NOT** dispatch generic Claude agents that just read files — they bypass graph and LLM tools.
</HARD-GATE>

**Graph agent:** Dispatch a **haiku** agent with this prompt (substitute `{{TASK}}`):

    You are a graph exploration agent. Use ToolSearch to find "code-review-graph" MCP tools, then:
    1. Run build_or_update_graph_tool (ensure graph is fresh)
    2. Run semantic_search_nodes_tool with feature keywords (try 2-3 variations)
    3. For relevant domains: query_graph_tool with "file_summary"
    4. For key files: query_graph_tool with "imports_of" and "importers_of"
    5. Return structured summary: Relevant Code, Domain Structure, Dependencies, Starting Points
    NEVER use get_architecture_overview_tool, list_communities_tool, or detect_changes_tool.
    If tools not found, return: GRAPH_UNAVAILABLE
    Task: {{TASK}}

Task: `explore "<feature keywords>" <project-root>`. If returns `GRAPH_UNAVAILABLE`, skip.

**LLM agent (MANDATORY):** Dispatch a **haiku** agent (parallel with graph) with this prompt (substitute `{{TASK}}`, `{{WORKING_DIR}}`, `{{KEEP_LOADED}}`):

    You are a local LLM agent. Run these bash commands — do NOT read code files yourself.
    Step 1: CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "llm-agent.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1)
    If empty, return: LLM_UNAVAILABLE
    Step 2: curl -s --max-time 2 http://127.0.0.1:1234 > /dev/null 2>&1 && echo LLM_AVAILABLE || echo LLM_UNAVAILABLE
    If LLM_UNAVAILABLE, return that immediately.
    Step 3 (timeout 300000ms): bash "$CRAFT_SCRIPTS/llm-agent.sh" "{{TASK}}" {{WORKING_DIR}}
    Step 4: Return findings. Filter out false positives about plugins/skills.
    Step 5 (skip if keep_loaded is true): bash "$CRAFT_SCRIPTS/llm-unload.sh"
    Keep loaded: {{KEEP_LOADED}}

Task: `explore "Investigate [2-3 domain paths relevant to the feature] for a [feature] feature. Check: 1) Existing types, services, and components 2) Patterns and conventions used 3) API endpoints if they exist. Give a structured summary." <project-root>`.
Keep loaded: `false` (standalone) or `true` (part of craft pipeline).

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
- Form fields use existing components where possible

Ask the user for approval:
- If approved → save plan and report its path
- If changes requested → send back to architect for revision

### Step 3: Save Plan

Save the approved plan to `.claude/plans/YYYY-MM-DD-{feature-name}.md` and report the path.

The plan is now ready for `craft-skills:develop` or `craft-skills:finalize`.
