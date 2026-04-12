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
| **`claude+llm-impl` (craft-ace)** | **yes** | **no** | **yes** | **yes** |

### Model Roles

| Role | Model | Rationale |
|---|---|---|
| Orchestrator, brainstorm, integration | **Opus** | Deep reasoning, cross-file, design decisions |
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
  skills/craft-ace/SKILL.md             Thin wrapper: profile=claude+llm-impl → /craft

MODIFIED files:
  skills/_craft-core/profiles.md        Add claude+llm-impl profile row
  skills/develop/SKILL.md               Add llm-impl dispatch routing + fallback logic
  skills/craft/SKILL.md                 Steps 1.10/2.4: llm-impl replaces agent reviews
```

## 4. LLM Implementer Script — `llm-implement.sh`

### Usage

```bash
llm-implement.sh <task-file> <working-dir> [ref-file1] [ref-file2] ...
```

- `task-file`: Path to a text file containing the full task description
- `working-dir`: Project root directory
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

### Output Format

The script instructs Gemma to end with a structured STATUS block:

```
--- STATUS ---
status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
files_changed: ["src/domain/x/data/models/x.ts", "src/domain/x/data/schemas/xSchemas.ts"]
exports_added: ["TypeX", "CreateXSchema"]
concerns: none | description of concerns
notes: optional notes for orchestrator
--- END STATUS ---
```

### Status Parsing

The script extracts the STATUS block and outputs JSON matching the existing `codex-status-schema.json` format:

```json
{
  "status": "DONE",
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

- Total context: 65,536 tokens
- System prompt + implementer rules: ~2K tokens
- Reference files (1-2 files): ~3-6K tokens
- Shared state: ~1-2K tokens
- Task description: ~0.5K tokens
- **Available for tool use + generation**: ~50K+ tokens
- Reference files truncated at 8K each if total pre-loaded context exceeds 15K

## 5. Reference File Selection

### Graph-First Algorithm

When dispatching a task to Gemma, the orchestrator selects reference files:

1. **Detect task type** from target file path pattern:
   - `**/data/models/*.ts` → types/models
   - `**/data/enums/*.ts` → enums
   - `**/data/schemas/*.ts` → schemas
   - `**/data/infrastructure/*Service.ts` → service class
   - `**/data/queries/*Queries.ts` → query hooks
   - `**/feature/**` → UI component
   - `**/data/mappers/*.ts` → mappers

2. **Search graph** for a matching reference:
   ```
   semantic_search_nodes_tool(task_type_keyword)
   → filter results by file path glob
   → pick top match as primary reference
   ```

3. **Discover dependencies** of the reference:
   ```
   imports_of(reference_file_path)
   → identifies apiService, models, shared utilities
   → feed key dependencies as additional context
   ```

4. **Feed to Gemma**: primary reference file + 1-2 key dependencies

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
    ├─ DONE → lint/tsc validation
    │     ├─ Clean → Accept ✓
    │     └─ Errors → Sonnet micro-fix agent
    │
    ├─ DONE_WITH_CONCERNS → Read concerns
    │     ├─ Minor (styling, naming) → Sonnet micro-fix agent
    │     └─ Major (wrong pattern, missing logic) → Sonnet full redo
    │
    ├─ NEEDS_CONTEXT → Provide info, re-dispatch to Gemma (once)
    │     ├─ Second attempt succeeds → Accept ✓
    │     └─ Second attempt fails → Sonnet full redo
    │
    └─ BLOCKED → Sonnet full redo
```

### Sonnet Fallback Details

When Sonnet takes over:
- Receives the **same task description** and reference files
- Also receives **Gemma's written files** as additional context (learns from the attempt)
- Uses the standard Claude Agent dispatch (not `llm-implement.sh`)
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

### Phase 2: Plan

| Step | Base craft | craft-ace |
|---|---|---|
| 2.1-2.3 (plan creation) | Opus | Opus (unchanged) |
| 2.4 Plan review | Sonnet agent | **Gemma** (replaces, not parallel) |

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

### Phase 4: Test — unchanged
### Phase 5: Report — unchanged

## 8. Profile Gating

The develop skill detects `llm-impl` in the profile:

```bash
CRAFT_PROFILE=$(cat "$PROJECT_ROOT/.craft-profile" 2>/dev/null || echo "claude")

case "$CRAFT_PROFILE" in
  *llm-impl*)
    LLM_IMPL_ENABLED=1
    LLM_REVIEW_ENABLED=1
    ;;
  *llm*)
    LLM_IMPL_ENABLED=0
    LLM_REVIEW_ENABLED=1
    ;;
  *)
    LLM_IMPL_ENABLED=0
    LLM_REVIEW_ENABLED=0
    ;;
esac
```

When `LLM_IMPL_ENABLED=1`:
- ALL implementation tasks routed to `llm-implement.sh` first
- Integration tasks still go to Opus agent (hardcoded exception)
- Fallback to Sonnet on DONE_WITH_CONCERNS (major), NEEDS_CONTEXT (2nd fail), or BLOCKED

## 9. Implementation Notes

- All `llm-*.sh` scripts currently default `LLM_MODEL` to `qwen/qwen3.5-35b-a3b`. The new `llm-implement.sh` must default to `google/gemma-4-26b-a4b`. Existing scripts should also be updated to the new default as part of this work.
- The `llm-check.sh` model detection (`grep -c "qwen3.5-35b-a3b"`) must be updated to detect Gemma instead.
- The `llm-agent.sh` auto-load logic (context length reload check) grep pattern must also be updated.

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

## 12. Cost Model

| Activity | Base craft | craft-ace | Savings |
|---|---|---|---|
| Brainstorm/orchestrate | Opus | Opus | 0% |
| Spec review | Opus agent | Gemma (local) | 100% |
| Plan review | Sonnet agent | Gemma (local) | 100% |
| Data layer impl (~40-50% LoC) | Sonnet agents | Gemma (local) | 100% |
| UI impl (~30-40% LoC) | Sonnet agents | Gemma → Sonnet fallback | ~50-70% |
| Integration (~10-20% LoC) | Opus agent | Opus agent | 0% |
| Post-develop review | — | Gemma (local) | free extra |
| **Estimated total** | | | **~50-65%** |
