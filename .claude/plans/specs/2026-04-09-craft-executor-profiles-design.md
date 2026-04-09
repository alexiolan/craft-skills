# Craft Executor Profiles — Design Spec

**Date:** 2026-04-09
**Target version:** craft-skills `1.1.0`
**Status:** Design approved, ready for implementation plan

## 1. Motivation

The current `craft` skill pipeline uses Claude (opus + sonnet) for all planning and execution, with local LLM via LM Studio for exploration and review. This is high-quality but expensive: feature runs consume significant Claude tokens and frequently hit rate limits on the Pro plan.

OpenAI's Codex CLI (`gpt-5-codex` / `codex-mini`) is now a credible executor for mechanical, pattern-following work:
- 2-4x fewer tokens than Claude for equivalent output
- ~40% cheaper per input token ($1.75 vs $3.00)
- Kernel-level sandboxing for safer batch execution
- Documented strength at scaffolding, boilerplate generation, well-scoped refactoring, TypeScript error fixing
- Documented weakness at React component work, ambiguous scope, cross-layer integration

This spec introduces four parallel `craft` variants that let the user choose an executor mix per run, offloading high-volume mechanical work to Codex while keeping Claude on the work where it wins.

## 2. Goals & non-goals

### Goals
- Add Codex as a first-class executor inside the `develop` phase for data-layer tasks
- Provide four clearly-named `craft` variants covering common AI-mix combinations
- Strip local LLM dependency from the base `/craft` path for reliability
- Preserve existing `/craft` behavior under a new `/craft-local` variant
- Generate `AGENTS.md` from `CLAUDE.md` automatically so Codex inherits project conventions
- Use direct `codex exec` subprocess invocation (not the `codex-plugin-cc` plugin) for deterministic dispatch

### Non-goals (deferred to future releases)
- Cost tracking / estimation / billing integration
- Parallel variants of `implement` and `finalize` skills
- Per-call token counting
- Cumulative history / time-series analysis
- Auto-detection of profile based on feature type (manual profile choice only)
- Routing *across* the four variants automatically

## 3. Architecture overview

**Four thin wrapper skills + one shared core.** The core contains all pipeline logic; each wrapper is ~30 lines that declares an executor profile and delegates to the core.

```
skills/
  _craft-core/                    NEW: shared pipeline logic (not a user-facing skill)
    core.md                       brainstorm → architect → develop → test steps
    profiles.md                   executor profile definitions + routing matrix
    codex-executor.md             Codex invocation guide
    llm-gating.md                 when to run LLM steps (per profile)

  craft/                          MODIFIED: becomes thin wrapper, profile = "claude"
    SKILL.md

  craft-duo/                      NEW: profile = "claude+codex"
    SKILL.md

  craft-local/                    NEW: profile = "claude+llm"
    SKILL.md

  craft-squad/                    NEW: profile = "claude+codex+llm"
    SKILL.md

  develop/                        MODIFIED: profile-aware routing
    SKILL.md
    implementer-prompt.md         unchanged (Claude agents)
    codex-prompt.md               NEW: prompt template for codex exec

  architect/                      MINOR EDIT: LLM pre-exploration profile-gated
    SKILL.md
    architect-prompt.md

  # Untouched
  bootstrap/ browser-test/ debug/ finalize/ graph-explore/
  implement/ llm-review/ reflect/ simplify/
```

The `_craft-core/` directory uses an underscore prefix convention signaling "internal, not a user-facing skill." Claude Code's skill discovery ignores directories without a `SKILL.md` at their own level.

## 4. Variant definitions

| Slash command | Profile | Claude | Codex | Local LLM | Graph tools | Mental model |
|---|---|---|---|---|---|---|
| `/craft` | `claude` | yes | no | no | yes | Default, simple, premium quality, no external deps |
| `/craft-duo` | `claude+codex` | yes | yes | no | yes | Cost-relief hybrid (recommended default for most runs) |
| `/craft-local` | `claude+llm` | yes | no | yes | yes | Free review layer via LM Studio (preserves pre-1.1 behavior) |
| `/craft-squad` | `claude+codex+llm` | yes | yes | yes | yes | Power-user mode, all three agents, adversarial review bonus |

**Key invariant:** Graph tools (`code-review-graph` MCP) are deterministic infrastructure, not AI. They are always on in every variant. Only AI components (Codex, local LLM) are gated by profile.

## 5. Profile propagation

**Mechanism:** `.craft-profile` marker file at project root.

- Wrapper SKILL.md writes the profile string to `.craft-profile` as its first step
- `_craft-core/core.md`, `architect/SKILL.md`, and `develop/SKILL.md` read this file to determine behavior
- File is deleted alongside `.shared-state.md` after a successful build
- If the file is missing, default profile is `claude` (backwards-compatible fallback)

**Rejected alternatives:**
- Shared-state section: `.shared-state.md` doesn't exist until develop phase; brainstorm/architect phases need profile earlier
- Embedded prompt context: fragile across long sessions; prior bugs in this plugin have come from "the agent forgets" failure modes

The file approach is explicit, debuggable, and robust against context loss.

## 6. Executor routing matrix

Applied per-task inside `develop` after the architect's plan is split into tasks.

### 6.1 Between-executor routing

| Task type | `claude` | `claude+codex` | `claude+llm` | `claude+codex+llm` |
|---|---|---|---|---|
| Data layer (types, services, queries, schemas, enums, mappers) | Claude sonnet | **Codex** | Claude sonnet | **Codex** |
| UI components (React feature/reusable) | Claude sonnet | Claude sonnet | Claude sonnet | Claude sonnet |
| Integration (wiring, routing, cross-component state) | Claude opus | Claude opus | Claude opus | Claude opus |
| Bulk mechanical fixes (lint/tsc repair sweeps) | Claude sonnet | **Codex** | Claude sonnet | **Codex** |

**Hard rules (derived from research):**
1. React components always stay on Claude. Codex's documented frontend weakness is the one place we never let it touch, even in `craft-squad`.
2. Integration tasks always stay on Claude opus. Multi-file reasoning is Claude's strong suit; Codex is an executor, not an architect.
3. Data layer is the only task category Codex owns when codex is in the profile. This category dominates per-feature token volume in the DDD architecture (5-7 files for one new domain: types, service, queries, schemas, enums, mappers).
4. Bulk mechanical fixes (currently dispatched as Claude sonnet "fix agents" when lint/tsc fails) are routed to Codex in profiles that include codex.

### 6.2 Within-Codex two-tier routing

When a task is routed to Codex, a second decision picks between the two Codex model tiers:

| Task filename pattern | Codex model | Rationale |
|---|---|---|
| `data/models/*.ts`, `data/enums/*.ts` | `codex-mini` | Pure type declarations, trivial |
| `data/schemas/*Schemas.ts` | `codex-mini` | Zod pattern-following, mechanical |
| `data/mappers/*.ts` | `codex-mini` | Formulaic API↔form transforms |
| `data/infrastructure/*Service.ts` | `gpt-5-codex` | HTTP client wiring, endpoint logic, error handling |
| `data/queries/*Queries.ts` | `gpt-5-codex` | Generics, factory function usage, cache keys |
| Bulk lint/tsc fixes | `codex-mini` | Documented strength of mini model per research |

Rough volume split: ~60% of Codex tasks go to `codex-mini`, ~40% to `gpt-5-codex`.

### 6.3 Expected delegation share

Based on typical DDD feature shape:

- Typical feature: **~30-40% of lines-of-code** routed to Codex under `craft-duo`
- New-domain feature (heavy data layer): ~40-50%
- UI-heavy feature: ~10-20%
- Mechanical refactor sweep: ~60-80%
- Pure integration/bugfix: ~0-10%

### 6.4 Parallelization rules

- Data layer tasks run first, in parallel with each other
- UI tasks run after data layer (they import the types)
- Integration tasks run last
- Codex and Claude agents can run in parallel within the same phase — a Codex data-layer run and a Claude UI run are independent processes

### 6.5 Shared-state coordination

Codex must participate in `.shared-state.md` the same way Claude agents do:

1. **Reading shared state before starting** — `.shared-state.md` contents injected into the Codex prompt by `develop` at dispatch time
2. **Writing outputs after completing** — Codex prompt instructs it to append created files / exports / dependencies to `.shared-state.md` as its last action before exiting
3. **Emitting a status code** — Codex prompt requires `DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED` (same protocol as Claude agents), enforced structurally via `--output-schema` JSON

**Reconcile safeguard:** after each Codex run, `develop` diff-checks `.shared-state.md` to verify it was actually updated. If Codex fails to append its outputs, a Claude sonnet "reconcile" agent is dispatched to inspect Codex's file changes and write the correct entries to shared state.

## 7. Codex technical integration

### 7.1 Invocation shape

```bash
codex exec \
  --full-auto \
  --sandbox workspace-write \
  -C "$PROJECT_ROOT" \
  --ephemeral \
  --output-schema "$CRAFT_SCRIPTS/codex-status-schema.json" \
  --output-last-message "$PROJECT_ROOT/.codex-output-$TASK_ID.json" \
  -m "$CODEX_MODEL" \
  - < "$PROJECT_ROOT/.codex-prompt-$TASK_ID.txt"
```

Flag rationale:
- `--full-auto` — sandboxed auto execution (workspace-write + on-request approvals)
- `-C` — explicit working directory (project root)
- `--ephemeral` — don't persist Codex session state; Claude Code owns session ownership
- `--output-schema` — structured JSON output for reliable status parsing (no text scraping)
- `--output-last-message` — captures final agent message to a file for develop to read back
- `-m` — model selection from the two-tier routing table
- Prompt piped via stdin — cleaner than arg for large prompts, avoids shell escaping

### 7.2 Status schema (new: `scripts/codex-status-schema.json`)

```json
{
  "type": "object",
  "required": ["status", "summary", "files_changed", "exports_added"],
  "properties": {
    "status": {
      "enum": ["DONE", "DONE_WITH_CONCERNS", "NEEDS_CONTEXT", "BLOCKED"]
    },
    "summary": { "type": "string" },
    "files_changed": { "type": "array", "items": { "type": "string" } },
    "exports_added": { "type": "array", "items": { "type": "string" } },
    "dependencies_added": { "type": "array", "items": { "type": "string" } },
    "concerns": { "type": "string" },
    "notes": { "type": "string" }
  }
}
```

Codex emits this JSON as its final message. `develop` reads the file, parses it, and routes to the next action.

### 7.3 Codex prompt template (new: `skills/develop/codex-prompt.md`)

Structured like `implementer-prompt.md` but tuned for Codex:
- Project context pointer (reference to `AGENTS.md` — Codex auto-loads it)
- DDD conventions relevant to the task
- The specific task from the architect's plan
- Relevant plan excerpts (dependencies, architecture decisions)
- Current `.shared-state.md` contents
- Pattern reference paths (e.g., "follow the pattern in `src/domain/customer/data/infrastructure/customerService.ts`")
- Hard constraints:
  - "Do NOT reformat unrelated code"
  - "Do NOT add files outside the task scope"
  - "Append your outputs to `.shared-state.md` before exiting"
  - "Emit final status JSON per the provided schema"

### 7.4 Error handling flow

```
Codex task dispatched
  ├─ Exit 0 + valid JSON + status=DONE
  │    → verify shared-state updated, proceed
  ├─ Exit 0 + valid JSON + status=DONE_WITH_CONCERNS
  │    → log concerns, decide if a fix agent is needed, proceed
  ├─ Exit 0 + valid JSON + status=NEEDS_CONTEXT
  │    → provide missing context from plan/shared-state, re-dispatch
  ├─ Exit 0 + valid JSON + status=BLOCKED
  │    → investigate blocker, fix root cause, re-dispatch
  ├─ Exit 0 + invalid JSON
  │    → log warning, dispatch Claude sonnet reconcile agent to review Codex's file changes
  └─ Exit non-zero
       → log stderr, dispatch Claude sonnet fallback agent for this specific task
```

**Claude fallback is important**: if Codex crashes or returns garbage, the whole pipeline must not die. Fall back to the existing Claude sonnet flow for that specific task, mark the fallback in `.shared-state.md`, and continue. The user sees the fallback in the final report.

### 7.5 Pre-flight check

In profiles that include codex, `develop` runs a pre-flight check before dispatching any tasks:

```bash
codex --version || { echo "ERROR: codex CLI not found. Install: npm i -g @openai/codex"; exit 1; }
```

No silent fallback to Claude. User explicitly chose a codex profile; if Codex isn't available, fail loud with actionable install instructions.

### 7.6 Authentication

Out of scope for this plugin. User configures once via `codex login` (ChatGPT auth) or `OPENAI_API_KEY` env var. Same pattern as Claude's auth.

## 8. AGENTS.md generation

### 8.1 Purpose

Codex reads `AGENTS.md` the way Claude reads `CLAUDE.md`. Without it, Codex has no baseline understanding of the project's DDD rules, form patterns, or domain boundaries.

### 8.2 Approach: generate from `CLAUDE.md` at bootstrap time

**New script:** `scripts/sync-agents-md.sh`

- Input: path to project root
- Reads `CLAUDE.md` from project root (and frontend shared CLAUDE.md if present)
- Writes `AGENTS.md` in project root with:
  - Contents of CLAUDE.md (copied verbatim)
  - Codex-specific preamble injected at top:
    - "Do NOT reformat existing code. Only change lines directly related to the task."
    - "Respect existing formatting and patterns."
    - "Use named exports, not default exports."
    - "Follow the DDD structure strictly."
- Wired into `bootstrap` skill as a standard step
- Also runs as a pre-flight check in `develop` when the profile includes codex: if `AGENTS.md` is missing or older than `CLAUDE.md`, regenerate before dispatching

### 8.3 Rejected alternatives

- **Symlink `AGENTS.md` → `CLAUDE.md`**: symlinks in git are fragile; Codex-specific guardrails can't be injected
- **Hand-maintain separate `AGENTS.md`**: drift is inevitable; single source of truth principle violated

## 9. Adversarial review bonus (optional)

When `codex-plugin-cc` (the official OpenAI Claude Code plugin) is installed and the profile includes codex, `develop` adds an optional adversarial review step after implementation and before verification:

- Invokes `/codex:adversarial-review` on the diff of implementation changes
- Captures findings, presents to the user
- Gated entirely on plugin presence: if not installed, step is silently skipped
- Only runs in `craft-duo` and `craft-squad` profiles

This gives a skeptical second-opinion code review from GPT-5-codex on Claude's output — a capability that's genuinely difficult to reproduce with raw `codex exec`.

**Not load-bearing**: the plugin is a bonus, not a dependency. Craft variants work fully without it.

## 10. Graph tools

**Always on in all four variants.** Graph tools (`code-review-graph` MCP) are deterministic infrastructure, not AI. They provide:
- Pre-exploration in `architect` phase (token-efficient structural search before architect agent runs)
- Post-develop review context for the review phase
- Impact radius analysis
- Semantic search across the codebase

No profile gates these. They run for `/craft`, `/craft-duo`, `/craft-local`, and `/craft-squad` identically.

## 11. LLM gating

Local LLM (LM Studio) paths are gated on profiles that include `llm`:

| Step | `claude` | `claude+codex` | `claude+llm` | `claude+codex+llm` |
|---|---|---|---|---|
| LLM pre-exploration in `architect` | skip | skip | run | run |
| LLM review in `develop` Step 3.5 | skip | skip | run | run |
| LLM model load / unload scripts | skip | skip | run | run |
| LM Studio availability check | skip | skip | run | run |

In `claude` and `claude+codex` profiles, LLM-related code paths are skipped entirely — no availability checks, no script execution, no failure modes. This is a meaningful reduction in the surface area of bugs for base `/craft`.

## 12. Breaking changes

| Change | Impact | Mitigation |
|---|---|---|
| `/craft` no longer runs LLM exploration/review | Users relying on LLM review see less investigation | `/craft-local` preserves pre-1.1 behavior exactly |
| `/craft` no longer needs LM Studio running | Positive — fewer failure modes | Documented in release notes |
| AGENTS.md must exist for codex profiles | New requirement | Bootstrap generates; develop pre-flight regenerates if missing/stale |
| New dependency: Codex CLI for `duo`/`squad` | User installs separately | Pre-flight check with clear install instructions; `/craft` and `/craft-local` have zero Codex dependency |

**Version bump:** `1.0.25` → `1.1.0` (minor). New skills + backwards-incompatible default for `/craft`. Strict semver would argue for `2.0.0`, but the break is mitigated by the one-keystroke migration path (`/craft` → `/craft-local`).

## 13. Rollout phases

Implementation sequence (each phase is independently testable and reversible):

1. **Shared core extraction** — pull existing `craft` logic into `_craft-core/core.md`. `/craft` now delegates to core. No behavior change. Refactor-only commit.
2. **Profile mechanism** — add `.craft-profile` read/write. `develop` reads it but ignores it initially. Verify nothing breaks.
3. **Strip LLM from `/craft`** — remove LLM exploration/review calls under the `claude` profile path. Verify `/craft` runs without LM Studio.
4. **Add `/craft-local`** — thin wrapper that sets profile `claude+llm`. Re-enables LLM paths via profile gating. Verify behavior matches pre-1.1 `/craft`.
5. **AGENTS.md generation** — add `sync-agents-md.sh`, wire into `bootstrap`. Verify `AGENTS.md` is generated and reasonable on a real frontend project.
6. **Codex dispatch in `develop`** — add `codex-prompt.md` template, dispatch logic, `--output-schema` status parsing, Claude fallback on failure, two-tier model routing. Profile-gated to `claude+codex` and `claude+codex+llm`.
7. **Add `/craft-duo`** — thin wrapper that sets profile `claude+codex`. End-to-end test on a real small feature.
8. **Add `/craft-squad`** — thin wrapper that sets profile `claude+codex+llm`. Wire adversarial review bonus gated on `codex-plugin-cc` presence.
9. **Update `CLAUDE.md` workflow table** — document the four variants in the craft-skills workflow section.
10. **Release** — bump version in `plugin.json` and `marketplace.json`, tag, push, publish.

Each phase ends with a smoke test on a real feature addition (e.g., "add a settings toggle" in one of the frontend projects) verified by `npm run lint && npx tsc --noEmit && npm run build`.

## 14. Rollback plan

Phases 1-4 are fully reversible by reverting the last commit.

Phases 6-8 add Codex dispatch. If Codex misbehaves on real projects:
- Users disable it by not invoking `/craft-duo` or `/craft-squad` — the old `/craft` still works
- Bug fixes target the codex dispatch code path without touching the Claude path
- Rolling back the whole feature means reverting phases 6-8 and shipping `1.1.1` with profile support but no Codex

The wrapper skills and profile mechanism are independent of the Codex dispatch implementation. They can ship even if Codex integration is disabled.

## 15. Open calibration items

Items that need measurement after initial rollout but don't block ship:

- **Codex prompt tuning** — the `codex-prompt.md` template will need iteration based on observed Codex output quality on real data-layer tasks
- **Reconcile agent trigger rate** — if Codex fails to update shared-state frequently, the template needs clearer instructions
- **Two-tier routing boundaries** — `codex-mini` vs `gpt-5-codex` split may need adjustment based on observed quality differences on real tasks
- **AGENTS.md effectiveness** — may need Codex-specific augmentation beyond the CLAUDE.md copy

These are calibration concerns, not design concerns. Address after 5-10 real runs.

## 16. Future work (explicitly out of scope for 1.1.0)

- `implement-duo`, `implement-local`, `implement-squad`, `finalize-duo`, etc. — parallel variants of other pipeline skills
- Cost tracking, estimation, and comparison reporting
- Cumulative run history / time-series analysis
- Auto-detection of profile from feature shape (e.g., "this plan is UI-heavy, use `/craft`")
- Codex for UI tasks (gated to plain presentational components only)
- Test scaffolding routed to Codex
- Storybook story generation routed to Codex
- Codex-mini for additional task categories
- Integration with Anthropic/OpenAI billing APIs
