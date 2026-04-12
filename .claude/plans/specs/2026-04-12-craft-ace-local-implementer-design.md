# craft-ace — Local LLM Implementer Design Spec

**Date:** 2026-04-12
**Target version:** craft-skills `1.2.0`
**Status:** Design approved, ready for implementation plan

## 1. Motivation

The current craft variants use Claude (opus + sonnet) for all implementation work, with the local LLM (Gemma 4 26B A4B 8-bit on LM Studio) limited to reviews. This works well but is expensive: sonnet agents handle ~80% of implementation LoC, and every agent dispatch costs API tokens.

Testing shows Gemma 4 26B is capable of producing production-quality implementation code when given project context files:
- **Data layer** (services, schemas, types, enums, mappers): Excellent — near-perfect pattern replication
- **React Query hooks**: Very Good — correct factory pattern usage, minor method name mismatches solvable with context
- **UI components**: Good — correct structure and DaisyUI usage, but occasional hook API misuse at integration points
- **Structured output**: 9-10/10 format compliance — reliably produces parseable `--- FILE: ---` / `--- STATUS ---` blocks

The key insight: Gemma excels at **self-contained, pattern-driven tasks** when fed 1-2 reference files. It struggles at **cross-file reasoning and integration** — which is exactly where Opus excels. This creates a natural role split.

## 2. Goals & Non-Goals

### Goals
- Add Gemma as a first-class **implementer** inside the `develop` phase for all task types
- Replace Sonnet agent reviews (spec, plan) with Gemma reviews (free)
- Implement try-Gemma-first with Sonnet fallback for UI components
- Use graph-assisted reference file selection for optimal context
- Achieve ~50-65% API cost reduction vs base `/craft`
- Create `llm-implement.sh` script for structured code generation with file writing

### Non-Goals
- Replacing Opus for orchestration or integration tasks
- Automatic profile detection (user chooses `craft-ace` explicitly)
- Gemma running without reference files (always context-assisted)
- Token counting or cost tracking per run
- Combining with Codex (`craft-ace` is Claude + Gemma only; a future `craft-ace-duo` could add Codex)

## 3. Architecture Overview

### Profile

| Profile value | Claude | Codex | LLM reviews | LLM implementation |
|---|---|---|---|---|
| `claude` (craft) | yes | no | no | no |
| `claude+llm` (craft-local) | yes | no | yes | no |
| `claude+codex` (craft-duo) | yes | yes | no | no |
| `claude+codex+llm` (craft-squad) | yes | yes | yes | no |
| **`claude+ace` (craft-ace)** | **yes** | **no** | **yes** | **yes** |

### Model Roles

| Role | Model | Rationale |
|---|---|---|
| Orchestrator, brainstorm, integration wiring | **Opus** | Deep reasoning, cross-file, design decisions |
| Spec review | **Gemma** (replaces Opus agent) | Tested excellent at review; free |
| Plan review | **Gemma** (replaces Sonnet agent) | Tested excellent at review; free |
| Data layer implementation | **Gemma** | Tested excellent with context files; free |
| UI component implementation | **Gemma → Sonnet fallback** | Try free first, pay only when needed |
| Integration/wiring implementation | **Opus agent** | Cross-file reasoning can't be delegated |
| Post-develop review | **Gemma** | Already proven in craft-local |
| Browser testing | **Haiku** | Unchanged |

### File Changes

```
NEW files:
  scripts/llm-implement.sh              LLM implementation agent with write_file tool
  skills/craft-ace/SKILL.md             Thin wrapper: profile=claude+ace → /craft
  scripts/llm-config.sh                 Shared model/URL/context defaults (sourced by all llm-*.sh)

MODIFIED files:
  skills/_craft-core/profiles.md        Add claude+ace profile row
  skills/develop/SKILL.md               Add ace dispatch routing + fallback logic
  skills/craft/SKILL.md                 Steps 1.10/2.4: ace profile replaces agent reviews
  scripts/llm-agent.sh                  Source llm-config.sh, remove hardcoded model defaults
  scripts/llm-review.sh                 Source llm-config.sh, remove hardcoded model defaults
  scripts/llm-analyze.sh                Source llm-config.sh, remove hardcoded model defaults
  scripts/llm-check.sh                  Source llm-config.sh, use $LLM_MODEL for detection
```

## 4. LLM Implementer Script — `llm-implement.sh`

**Relationship to `llm-agent.sh`**: The new script extends the Python agent loop from `llm-agent.sh` (message threading, tool dispatch, context tracking, truncation). It adds the `write_file` tool, pre-loads reference files into the system prompt, and adds STATUS block parsing at the end. The two scripts share the same loop structure but are separate files — the differences in system prompt assembly, tool set, and output parsing make a shared Python module unnecessary at this stage. If they drift, a future refactor can extract the common agent loop into `llm-agent-core.py`.

### Usage

```bash
llm-implement.sh <task-file> <working-dir> <allowed-files> [ref-file1] [ref-file2] ...
```

- `task-file`: Path to a text file containing the full task description
- `working-dir`: Project root directory
- `allowed-files`: Comma-separated list of file paths that `write_file` is allowed to create/modify (extracted from the plan step by the orchestrator). Example: `src/domain/notifications/data/models/notification.ts,src/domain/notifications/data/schemas/notificationSchemas.ts`
- `ref-file1, ref-file2, ...`: Reference files to pre-load into context

### System Prompt Assembly

The script builds the system prompt from these layers (in order):

1. **Implementer role** — condensed version of `implementer-prompt.md` rules
2. **Output format instructions** — the `--- FILE: ---` / `--- STATUS ---` format
3. **Reference file contents** — pre-loaded, not fetched via tool calls
4. **Shared state** — current `.shared-state.md` content
5. **Task description** — from the task file

### Tools Available

Same as `llm-agent.sh` plus one addition:

| Tool | Purpose | From |
|---|---|---|
| `read_file(path)` | Read source files | Existing |
| `list_dir(path)` | Browse directories | Existing |
| `search_code(pattern, path)` | Grep for patterns | Existing |
| `write_file(path, content)` | **Write implementation files** | **New** |
| `git_log(path, count)` | Check history | Existing |
| `git_diff(ref)` | Check changes | Existing |

### Write Safety

The `write_file` tool enforces guardrails:
- **Path restriction**: Only allows writes under the `working-dir`. Rejects absolute paths or `../` traversal.
- **Scope restriction**: Checks the path against the `allowed-files` list passed to the script. Writes to unlisted paths return an error to the LLM: `"ERROR: path not in task scope. If this file is necessary, report NEEDS_CONTEXT with the path in your concerns."` The orchestrator treats this as a NEEDS_CONTEXT signal — it can either add the path to the allowed list and re-dispatch, or escalate to Sonnet.
- **Overwrite guard**: If the target file exists, `write_file` logs a warning to stderr (`WARN: overwriting existing file <path>`) but allows the write. The orchestrator reviews the `git diff --stat` post-check to catch unintended modifications.
- **Atomic writes**: `write_file` writes to a temp file first (`<path>.tmp`), then renames to the final path. This prevents partial/corrupt files if the LLM context overflows or the script crashes mid-write.
- **Multi-write behavior**: If Gemma calls `write_file` on the same path multiple times, each call fully replaces the file content (last-write-wins). This is intentional — Gemma may iterate on a file within a single session.
- After all writes, the orchestrator runs `git diff --stat` to verify only expected files were touched before proceeding to lint/tsc.

### Shared State Update

Gemma does NOT write to `.shared-state.md` directly. Instead:
1. The script parses Gemma's STATUS block into JSON
2. The **orchestrator** updates `.shared-state.md` on Gemma's behalf, using the parsed `files_changed`, `exports_added`, and `notes` fields
3. This is more robust than giving Gemma write access to shared state (avoids format corruption, merge conflicts with other agents)

### Output Format

The script instructs Gemma to end with a structured STATUS block:

```
--- STATUS ---
status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
severity: none | minor | major
files_changed: ["src/domain/x/data/models/x.ts", "src/domain/x/data/schemas/xSchemas.ts"]
exports_added: ["TypeX", "CreateXSchema"]
concerns: none | description of concerns
notes: optional notes for orchestrator
--- END STATUS ---
```

The `severity` field enables automated routing:
- `none` — used with DONE status
- `minor` — styling, naming, non-functional issues → micro-fix agent
- `major` — wrong pattern, missing logic, structural problems → full redo

### Status Parsing

The script extracts the STATUS block and outputs JSON matching the existing `codex-status-schema.json` format:

```json
{
  "status": "DONE",
  "severity": "none",
  "summary": "Created notification types and schemas",
  "files_changed": ["path/a.ts", "path/b.ts"],
  "exports_added": ["TypeA", "SchemaB"],
  "dependencies_added": [],
  "concerns": "",
  "notes": ""
}
```

This allows the develop orchestrator to use identical routing logic for Gemma and Codex results.

### Context Budget

All limits below are in **characters** (code averages ~3.5 chars/token, so 20K chars ≈ 5.7K tokens).

- Total context: 65,536 tokens (~230K chars)
- System prompt + implementer rules: ~7K chars (~2K tokens)
- Reference files (max 3 files, max 20K chars): ~5-7K tokens
- Shared state: ~4K chars max (~1.1K tokens)
- Task description: ~2K chars (~0.5K tokens)
- **Available for tool use + generation**: ~45K+ tokens

**Truncation rules:**
- Each reference file capped at 8K characters
- Total pre-loaded reference content capped at 20K characters
- If 3 files exceed 20K combined, the orchestrator drops the least relevant dependency (keeps primary reference + 1 dependency)
- Shared state capped at 4K characters (older entries trimmed first)

## 5. Reference File Selection

### Graph-First Algorithm

When dispatching a task to Gemma, the orchestrator selects reference files:

1. **Detect task type** from the plan's **target file path** (the path the task says to create/modify — this is specified in the plan, not discovered from disk):
   - `**/data/models/*.ts` → types/models
   - `**/data/enums/*.ts` → enums
   - `**/data/schemas/*.ts` → schemas
   - `**/data/infrastructure/*Service.ts` → service class
   - `**/data/queries/*Queries.ts` → query hooks
   - `**/feature/**` → UI component
   - `**/data/mappers/*.ts` → mappers

2. **Search graph** for a matching existing reference (same file type in a different domain):
   ```
   semantic_search_nodes_tool(task_type_keyword)
   → filter results by file path glob matching the task type
   → exclude the target domain (find a reference from a DIFFERENT domain)
   → pick top match as primary reference
   ```

3. **Discover dependencies** of the reference (max 2 levels, max 3 files total):
   ```
   imports_of(reference_file_path)
   → identifies apiService, models, shared utilities
   → pick at most 2 key dependencies (prioritize: HTTP client > models > utilities)
   → STOP — do not recurse into dependencies of dependencies
   ```

4. **Feed to Gemma**: primary reference file + 1-2 key dependencies (max 3 files, max 20K chars total)

### Glob Fallback

If no graph exists for the target project or graph returns 0 results:
- Use `Glob` to find `**/{task-type-pattern}` in the project
- Pick the first match as reference
- No dependency discovery (Gemma uses its tools to explore if needed)

### Reference Selection Table

| Task type | Primary reference (graph search) | Additional context (via imports_of) |
|---|---|---|
| Types/models | Existing `**/data/models/*.ts` | — |
| Enums | Existing `**/data/enums/*.ts` | — |
| Schemas | Existing `**/data/schemas/*.ts` | Related enum file (if schema uses enums) |
| Service class | Existing `**/infrastructure/*Service.ts` | `apiService.ts` (HTTP client) |
| Query hooks | Existing `**/queries/*Queries.ts` | The service file being consumed |
| UI list/table | Existing feature list page | Query hooks file for the domain |
| UI form | Existing feature form page | `useAppForm.ts` + schema file |
| UI detail | Existing feature detail page | Query hooks file for the domain |
| Mappers | Existing `**/data/mappers/*.ts` | Models file for the domain |

## 6. Try-Gemma-First Fallback Mechanism

### Flow

```
Dispatch to Gemma (llm-implement.sh)
    │
    ├─ DONE (severity: none) → lint/tsc validation
    │     ├─ Clean → Accept ✓
    │     └─ Errors → Sonnet micro-fix agent
    │
    ├─ DONE_WITH_CONCERNS (severity: minor) → Sonnet micro-fix agent
    │
    ├─ DONE_WITH_CONCERNS (severity: major) → Sonnet full redo
    │
    ├─ NEEDS_CONTEXT → Provide info, re-dispatch to Gemma (once)
    │     ├─ Second attempt succeeds → Accept ✓
    │     └─ Second attempt fails → Sonnet full redo
    │
    └─ BLOCKED → Sonnet full redo
```

### Sonnet Micro-Fix Agent

A lightweight Sonnet agent dispatched for minor issues (lint errors, naming, small pattern deviations):
- **Dispatch mechanism**: Standard Claude `Agent` tool with `model: "sonnet"`
- **Prompt template**: Inline in the develop skill (not a separate file — it's ~5 lines):
  ```
  Fix the following lint/tsc errors in the files below. Make minimal targeted changes — do not rewrite files.
  Use the reference file to understand the expected patterns.
  Errors: {lint_tsc_output}
  Reference: {reference_file_path}
  Files to fix: {list_of_file_paths}
  ```
- **Context**: the specific file(s) Gemma wrote + lint/tsc error output + the primary reference file
- Does NOT receive the full task description or shared state (unnecessary for small fixes)
- **Tools**: Standard Claude agent tools (Read, Edit, Bash for running lint/tsc)
- **Status reporting**: Not required — the orchestrator re-runs lint/tsc after the micro-fix agent completes. If still failing, escalates to Sonnet full redo.
- Expected to complete in a single pass

### Sonnet Full Redo

A standard Sonnet implementation agent dispatched when Gemma's output is fundamentally wrong:
- Receives the **same task description** and reference files as Gemma got
- Also receives **Gemma's written files** as additional context (learns from the attempt)
- Uses the standard Claude Agent dispatch with `implementer-prompt.md`
- Produces files directly (no STATUS block parsing needed)

### Dispatch Log

The orchestrator appends to `.shared-state.md`:

```markdown
## LLM Dispatch Log
- Task 2.1 (NotificationService): GEMMA → DONE ✓
- Task 2.2 (NotificationSchemas): GEMMA → DONE ✓
- Task 2.3 (NotificationList): GEMMA → DONE_WITH_CONCERNS → SONNET micro-fix ✓
- Task 2.4 (NotificationForm): GEMMA → BLOCKED → SONNET fallback ✓
```

This helps the integration review (Step 3) identify files that had bumpy paths.

## 7. Pipeline Phase Changes

### Phase 1: Brainstorm

| Step | Base craft | craft-ace |
|---|---|---|
| 1.1 LLM pre-exploration | skipped | **enabled** (Gemma explores codebase) |
| 1.2-1.9 (design flow) | Opus | Opus (unchanged) |
| 1.10 Spec review | Opus agent | **Gemma** (replaces, not parallel) |
| 1.11 LLM spec review | skipped | **merged into 1.10** (Gemma does both) |

**Gating logic for Step 1.10 in `craft/SKILL.md`:**
```
if CRAFT_PROFILE == "claude+ace":
    SKIP opus agent spec review dispatch
    RUN llm-review.sh with spec file as sole reviewer
elif CRAFT_PROFILE matches *llm*:
    RUN opus agent spec review (existing behavior)
    RUN llm-review.sh in PARALLEL (existing behavior)
else:
    RUN opus agent spec review only (existing behavior)
```

### Phase 2: Plan

| Step | Base craft | craft-ace |
|---|---|---|
| 2.1-2.3 (plan creation) | Opus | Opus (unchanged) |
| 2.4 Plan review | Sonnet agent | **Gemma** (replaces, not parallel) |

**Gating logic for Step 2.4 in `craft/SKILL.md`:**
```
if CRAFT_PROFILE == "claude+ace":
    SKIP sonnet agent plan review dispatch
    RUN llm-review.sh with plan file as sole reviewer
elif CRAFT_PROFILE matches *llm*:
    RUN sonnet agent plan review (existing behavior)
    RUN llm-review.sh in PARALLEL (existing behavior)
else:
    RUN sonnet agent plan review only (existing behavior)
```

### Phase 3: Develop

| Step | Base craft | craft-ace |
|---|---|---|
| 0 Pre-flight | Claude check | Claude + LM Studio check |
| 1 Shared state | unchanged | unchanged |
| 2 Dispatch | Sonnet agents (all tasks) | **Gemma all tasks, Opus integration only** |
| 2 (fallback) | — | **Sonnet fallback for failed Gemma UI tasks** |
| 3 Integration review | Opus | Opus (unchanged) |
| 3.5 Post-develop review | skipped | **Gemma** (enabled) |
| 4 Verification | lint/tsc/build | lint/tsc/build (unchanged) |
| 5 Cleanup | unchanged | unchanged |

**Gating logic for Step 3.5 in `develop/SKILL.md`:**
```
if CRAFT_PROFILE == "claude+ace":
    RUN llm-review.sh on created/modified files (from shared state)
    RUN graph review (auto-detects changed files from git)
elif CRAFT_PROFILE matches *llm*:
    RUN llm-review.sh (existing behavior)
    RUN graph review (existing behavior)
else:
    SKIP post-develop LLM review
```

### Phase 4: Test — unchanged
### Phase 5: Report — unchanged

## 8. Profile Gating

The develop skill detects the profile using exact string matching. The profile `claude+ace` does NOT contain the substring `llm`, so it will NOT trigger any existing `*llm*` glob gates in the codebase. This avoids double-execution of review steps.

```bash
CRAFT_PROFILE=$(cat "$PROJECT_ROOT/.craft-profile" 2>/dev/null || echo "claude")

# Exact profile matching — no substring wildcards
case "$CRAFT_PROFILE" in
  "claude+ace")
    LLM_IMPL_ENABLED=1
    LLM_REVIEW_ENABLED=1
    ;;
  "claude+llm"|"claude+codex+llm")
    LLM_IMPL_ENABLED=0
    LLM_REVIEW_ENABLED=1
    ;;
  *)
    LLM_IMPL_ENABLED=0
    LLM_REVIEW_ENABLED=0
    ;;
esac
```

**Why `claude+ace` instead of `claude+llm-impl`**: The existing codebase gates LLM steps with `*llm*` glob patterns. A profile containing `llm` would match those gates and cause double-execution (existing LLM review + new Gemma replacement). Using `ace` avoids this collision entirely — no existing gates need modification.

When `LLM_IMPL_ENABLED=1`:
- ALL implementation tasks routed to `llm-implement.sh` first
- **Integration wiring** tasks still go to Opus agent (hardcoded exception)
- Fallback to Sonnet on DONE_WITH_CONCERNS (major), NEEDS_CONTEXT (2nd fail), or BLOCKED

### Integration vs Data Layer Boundary

The orchestrator classifies tasks by their **target file path**, not by conceptual role:

| Target file pattern | Classification | Executor |
|---|---|---|
| `**/data/models/*.ts` | Data layer | Gemma |
| `**/data/enums/*.ts` | Data layer | Gemma |
| `**/data/schemas/*.ts` | Data layer | Gemma |
| `**/data/infrastructure/*Service.ts` | Data layer | Gemma |
| `**/data/queries/*Queries.ts` | Data layer | Gemma |
| `**/data/mappers/*.ts` | Data layer | Gemma |
| `**/feature/**` | UI component | Gemma → Sonnet fallback |
| `**/ui/**` | UI component | Gemma → Sonnet fallback |
| Route registration, layout wiring, provider setup | Integration wiring | Opus agent |
| Tasks the plan explicitly marks as "integration" | Integration wiring | Opus agent |

**Classification rules:**
1. **Primary rule**: Classification is determined by **target file path pattern** (the table above).
2. **Integration override**: The plan may explicitly mark a task as "integration" regardless of file path — the orchestrator respects this.
3. **Multi-file tasks**: If a plan step lists multiple target files (e.g., model + schema), the orchestrator dispatches them as **one Gemma task** if all files are within the same domain and layer (e.g., both under `data/`). If files span different layers (e.g., `data/` + `feature/`), the orchestrator splits into sub-tasks before dispatch.
4. **Query hooks** (`*Queries.ts`) are classified as **data layer**, not integration, because they follow a rigid factory pattern with a single service dependency.
5. **Integration wiring** is reserved for tasks that connect multiple domains or layers together (e.g., adding a route, wiring a provider, composing multiple domain hooks in a page).

## 9. Implementation Notes

### Model Configuration Refactor (Prerequisite — separate PR)

This refactor touches every existing `llm-*.sh` script and changes the default model from Qwen to Gemma. It should be shipped as a separate PR before craft-ace implementation to allow independent testing and rollback.

- **Single source of truth**: Create `scripts/llm-config.sh` that exports `LLM_MODEL`, `LLM_URL`, and `LLM_CONTEXT_LENGTH` as defaults. All other `llm-*.sh` scripts source this file.
- **Default model**: `google/gemma-4-26b-a4b`
- **Default context**: `65536`
- **Default URL**: `http://127.0.0.1:1234`
- **Model detection**: Replace all `grep -c "qwen3.5-35b-a3b"` patterns with `grep -c "$LLM_MODEL"` — detect based on the configured model variable, not a hardcoded string.
- **Auto-load logic**: `lms load "$LLM_MODEL" -c "$LLM_CONTEXT_LENGTH"` — uses variables, not hardcoded values.
- **Override**: Users can still set `LLM_MODEL` env var to use a different model without editing scripts.
- **Sourcing**: Each `llm-*.sh` script adds `source "$(dirname "$0")/llm-config.sh"` near the top, after the usage/help block.

## 10. Prerequisites

| Requirement | How verified | Failure mode |
|---|---|---|
| LM Studio running | `llm-check.sh` (curl health check) | Loud fail — profile requires LLM |
| Gemma 4 26B loaded | `lms ps` check in `llm-implement.sh` | Auto-load with 65K context |
| Graph built on target project | `semantic_search_nodes_tool` returns results | Silent fallback to Glob |

## 11. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Gemma hallucinates imports without context | Low (with ref files) | Medium | Graph-assisted reference selection |
| UI components need Sonnet fallback often | Medium | Low (still saves on data layer) | Try-Gemma-first; only pay when needed |
| 65K context too small for complex tasks | Low | Medium | Orchestrator controls context; plan splits large tasks |
| LM Studio not running | Low | High (blocks pipeline) | `llm-check.sh` + loud fail |
| Unparseable STATUS block | Very low | Low | Treat as DONE_WITH_CONCERNS → Sonnet validation |
| Gemma quality degrades on future model updates | Low | Medium | Model pinned in config; test before upgrading |
| Gemma writes to unexpected file paths | Very low | High | `write_file` tool restricts to task's expected paths + `git diff --stat` post-check |
| Model string detection breaks on version change | Medium | Medium | `llm-config.sh` single source of truth; no hardcoded model strings in other scripts |
| Orchestration complexity causes misinterpretation | Medium | Medium | Dispatch routing, fallback logic, and reference selection are prose in develop/SKILL.md. Keep instructions structured with clear conditionals. Test with dry-run features before full pipeline runs. |
| Gemma produces truncated/corrupt files | Low | Medium | Atomic writes (temp file + rename) prevent partial files. Lint/tsc catches syntax errors. |

## 12. Cost Model

| Activity | Base craft | craft-ace | Savings |
|---|---|---|---|
| Brainstorm/orchestrate | Opus | Opus | 0% |
| Spec review | Opus agent | Gemma (local) | 100% |
| Plan review | Sonnet agent | Gemma (local) | 100% |
| Data layer impl (~40-50% LoC) | Sonnet agents | Gemma (local) | 100% |
| UI impl (~30-40% LoC) | Sonnet agents | Gemma → Sonnet fallback | ~30-50% |
| Integration (~10-20% LoC) | Opus agent | Opus agent | 0% |
| Post-develop review | — | Gemma (local) | free extra |
| **Estimated total** | | | **~45-60%** |

**Cost model assumptions:**
- UI savings estimated conservatively at 30-50% because Gemma tested only "Good" on UI components. Failed Gemma attempts add latency (Gemma run time + Sonnet fallback) without saving tokens.
- If UI fallback rates exceed 60%, consider routing UI tasks directly to Sonnet (skip try-Gemma-first for `**/feature/**` and `**/ui/**` paths). This simplifies the pipeline while still capturing ~40-50% savings from data layer + reviews alone.
- Actual savings depend on feature complexity. Data-heavy features (new domain, CRUD) save more; UI-heavy features (dashboards, complex forms) save less.
