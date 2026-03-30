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

### Step 1: Dispatch Architect Agent

Dispatch an **implementation-architect** agent using the Agent tool. Read the agent prompt template from the `architect-prompt.md` file in this skill's directory, then append the requirements to it.

The agent should:
1. Read the project's CLAUDE.md thoroughly
2. Investigate the codebase for relevant patterns, existing code, and reusable components
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
