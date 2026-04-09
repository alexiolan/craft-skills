---
name: develop
description: "Use when an approved implementation plan exists and is ready to be executed. Initializes shared state, dispatches parallel frontend-developer agents, performs integration review, and runs full verification (lint, tsc, format, build)."
---

# Develop

Execute an approved implementation plan using parallel frontend-developer agents.

## Input

The user input is: `$ARGUMENTS`

- **Plan path** (e.g., `.claude/plans/2026-03-16-pricing-detail-modal.md`): Use this plan
- **Empty**: Auto-detect the most recent `.md` file in `.claude/plans/` (excluding `archive/` and `specs/`)

If no plan is found, tell the user to run `craft-skills:architect` or `craft-skills:craft` first.

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

## Step 1: Initialize Shared State

Create a fresh `.shared-state.md` at the project root (delete if one exists from a previous run):

```markdown
# Shared Agent State

> Auto-generated during implementation. Do not edit manually.
> This file is deleted after a successful build.

## Architecture Decisions

<!-- Key decisions carried over from the plan -->

## Created / Modified Files

<!-- Format: - path/to/file.ts (exports: Name1, Name2) -->

## Shared Types & Interfaces

<!-- Format: - InterfaceName — path/to/types.ts — brief description -->

## Dependencies Added

<!-- Format: - package-name (reason for adding) -->

## Notes & Warnings

<!-- Anything other agents should be aware of -->
```

Populate **Architecture Decisions** with key decisions from the plan before dispatching any tasks.

## Step 2: Dispatch Tasks

Read the plan and split it into tasks. Identify which tasks can run in parallel (no dependencies) and which must be sequential.

Dispatch tasks to **frontend-developer** agents. Read the agent prompt template from the `implementer-prompt.md` file in this skill's directory and provide it as context to each agent along with their specific task.

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

Each agent **MUST**:
1. **Read** `.shared-state.md` before starting work
2. **Read** the full plan for their task's context
3. **Read** the project's CLAUDE.md for conventions
4. **Append** their outputs (created files, exported types, dependencies) to shared state after completing
5. **Check** if another agent has already created something they need — import and reuse
6. **Flag** any conflicts or ambiguities in **Notes & Warnings**

**Parallelization rules:**
- Tasks that create independent files with no imports between them → parallel
- Tasks that depend on types/exports from earlier tasks → sequential
- Data layer tasks (types, service, queries) typically run first
- UI component tasks often run in parallel after data layer is done
- Integration tasks (wiring components together) run last

**Implementer status protocol:**
Each agent MUST end their work with one of these status codes:
- **DONE** — Task completed successfully, no concerns
- **DONE_WITH_CONCERNS** — Task completed but with caveats (describe what and why)
- **NEEDS_CONTEXT** — Blocked on missing information from another agent's output or the plan
- **BLOCKED** — Cannot proceed due to an error, conflict, or ambiguity

**Two-stage quality approach:**
After each agent completes, check their status:
- **DONE** → Quick spec compliance check: did they follow the plan? Are exports consistent with shared state?
- **DONE_WITH_CONCERNS** → Review concerns, decide if they need a fix agent or are acceptable
- **NEEDS_CONTEXT** → Provide the missing context and re-dispatch
- **BLOCKED** → Investigate the blocker, fix the root cause, then re-dispatch

If issues found during spec compliance check, dispatch a targeted fix agent before proceeding.

## Step 3: Integration Review

After all agents complete, review `.shared-state.md` holistically:

- Duplicate exports or conflicting type definitions
- Cross-references between agent outputs are consistent
- Naming, patterns, and conventions are consistent
- **Notes & Warnings** section has no unresolved issues

If issues found, dispatch targeted fixes to frontend-developer agents. Repeat until consistent.

## Step 3.5: Post-Develop Review

Before running verification, use graph + LLM to review created/modified files from `.shared-state.md`. Claude should NOT read the implementation files itself — let LLM do the reading.

Run graph tools and LLM bash directly — no dedicated agents for these.

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

**Step B — Start LLM review in background (if available AND profile includes llm):**

Skip if Step A returned `LLM_SKIPPED_BY_PROFILE` or `LLM_UNAVAILABLE`. Otherwise run with Bash tool (`run_in_background: true`, timeout 300000ms):

```bash
CRAFT_PROFILE=$(cat .craft-profile 2>/dev/null || echo "claude")
case "$CRAFT_PROFILE" in
  *llm*)
    CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "llm-agent.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1)
    bash "$CRAFT_SCRIPTS/llm-agent.sh" "Review these files for bugs, missing imports, type mismatches, pattern violations, and DDD boundary violations: [file list from .shared-state.md or graph results]." <project-root>
    bash "$CRAFT_SCRIPTS/llm-unload.sh"
    ;;
  *)
    echo "LLM_REVIEW_SKIPPED_BY_PROFILE"
    ;;
esac
```

If Step A returned `LLM_UNAVAILABLE` (but profile includes llm), fall back to reading only integration/wiring files.

If Step A returned `LLM_SKIPPED_BY_PROFILE`, the graph review in Step C is the only post-develop review — no file-reading fallback.

**Step C — Run graph review (while LLM processes):**

Load graph MCP tools via ToolSearch (search for "code-review-graph"), then run:
1. `build_or_update_graph_tool` — capture new files
2. `get_review_context_tool` — auto-detects changed files from git

**NEVER** use `get_architecture_overview_tool`, `list_communities_tool`, or `detect_changes_tool`.

Claude receives only the findings — **do not read the implementation files yourself**. Filter out false positives about plugins/skills.

**Step C — Act on findings:**
If either review surfaces issues, dispatch targeted **sonnet** fix agents before proceeding to verification.

## Step 4: Verification

**Iron Law: No completion claims without running these commands AND reading their output.**

Run the full verification sequence:

1. `npm run lint` — fix any errors via agents, repeat until clean
2. `npx tsc --noEmit` — fix any type errors, repeat until clean
3. `npm run format` — format the codebase
4. `npm run build` — fix any build errors, repeat from appropriate step

If a step fails repeatedly (3+ attempts), stop and ask the user for guidance.

## Step 5: Cleanup

After a successful build:

1. Delete `.shared-state.md`
2. Delete `.craft-profile` (if it exists — may be missing when `develop` is invoked standalone)
3. Report a summary of all changes made, files created/modified, and any decisions worth noting
