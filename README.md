# craft-skills

A [Claude Code](https://claude.ai/code) plugin providing structured development skills for any project.

Replaces generic AI workflows with battle-tested, structured processes: collaborative brainstorming, planning, parallel agent development, testing, systematic debugging, and self-improvement. Works with any tech stack — frontend, backend, or full-stack.

## Installation

```
/plugin marketplace add alexiolan/craft-skills
/plugin install craft-skills@craft-skills
```

### Updating

```
/plugin update craft-skills@craft-skills
```

> **Note:** Claude Code has a known bug where `plugin update` may report "already at latest" even when a new version exists. If that happens, run this in your terminal first, then retry the update:
> ```bash
> git -C ~/.claude/plugins/marketplaces/craft-skills pull --ff-only
> ```

## Skills

### Pipeline Skills (Craft Variants)

All craft variants share the same pipeline: **Brainstorm → Plan → Develop → Test → Report**. They differ in which models handle each phase:

| Skill | Who implements | Who reviews | Requirements | Cost savings |
|---|---|---|---|---|
| **craft** | Claude (Sonnet) | Claude (Opus/Sonnet) | None | Baseline |
| **craft-ace** | Gemma (local LLM) | Gemma (review loops) | LM Studio | ~45-60% |
| **craft-duo** | Claude + Codex | Claude (Opus/Sonnet) | Codex CLI | ~15-20% |
| **craft-local** | Claude (Sonnet) | Claude + Gemma | LM Studio | ~0% (quality boost) |
| **craft-squad** | Claude + Codex | Claude + Gemma | Codex CLI + LM Studio | ~15-20% |

**Choosing a variant:**
- **No external deps?** Use `craft`
- **Want cost savings?** Use `craft-ace` (requires LM Studio with Gemma)
- **Want deeper review?** Use `craft-local` (requires LM Studio)
- **Have Codex CLI?** Use `craft-duo` or `craft-squad`

### Shortcut Pipeline Skills

| Skill | Description |
|---|---|
| **implement** | Fast pipeline: architect → develop → test. For clear, well-understood requirements. |
| **finalize** | Post-plan pipeline: develop → test. Use when a plan already exists. |

### Process Skills

| Skill | Description |
|---|---|
| **architect** | Analyze requirements and create a detailed implementation plan. No code written. |
| **develop** | Execute an approved plan using parallel agents with shared state coordination. |
| **browser-test** | Plan and run parallel browser-based UI tests using multiple agents. |
| **debug** | Systematic root-cause investigation before attempting any fix. |
| **simplify** | Review changed code for reuse opportunities, quality, and architecture compliance. |
| **reflect** | Self-improvement: audit project configs, maintain skill health, sync upstream. |
| **llm-review** | Run a local LLM review on files. Auto-loads/unloads model. |
| **graph-explore** | Explore codebase structure using the code-review-graph knowledge graph. |

### System Skills

| Skill | Description |
|---|---|
| **bootstrap** | Loaded at SessionStart. Establishes skill awareness and auto-trigger rules. |

## How It Works

### Automatic triggering

The bootstrap skill loads at every session start and watches for trigger conditions:

- "Add a reviews domain" → triggers **craft** or **implement**
- "The API returns 500 after saving" → triggers **debug**
- "Audit the Claude configs" → triggers **reflect**

### Manual invocation

```
/craft Add a notification preferences page
/craft-ace Build a reporting dashboard
/implement 15
/debug The form validation isn't working
/reflect project
```

### Input types

Pipeline skills accept three input formats:

- **Prompt file number**: `/craft 15` reads `.claude/prompts/15-*.md`
- **Direct text**: `/implement Add a logout button`
- **Empty**: auto-detects recent plans or asks for input

## How craft-ace Works

`craft-ace` is the cost-optimized variant where a local LLM (Gemma 4 26B) handles implementation and reviews, while Claude Opus orchestrates.

**Role split:**

| Role | Model | Cost |
|---|---|---|
| Orchestrator, brainstorm, integration | Opus | Paid |
| Spec & plan reviews (up to 4 rounds each) | Gemma | Free |
| Data layer implementation (types, services, schemas, queries) | Gemma | Free |
| UI component implementation | Gemma first, Sonnet fallback | Mostly free |
| Post-develop review | Gemma | Free |

**How Gemma implements code:**
1. Orchestrator selects reference files from the codebase (via knowledge graph or glob)
2. `llm-implement.sh` sends the task + reference files to Gemma
3. Gemma writes files using a `write_file` tool (scope-restricted, atomic writes)
4. Returns structured JSON status (DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED)
5. If Gemma fails, Sonnet takes over with Gemma's attempt as additional context

## Architecture

```
craft-skills/
├── .claude-plugin/
│   ├── plugin.json              # Plugin manifest
│   └── marketplace.json         # GitHub marketplace definition
├── skills/
│   ├── _craft-core/             # Shared pipeline logic
│   │   ├── core.md              # Pipeline phases
│   │   ├── profiles.md          # Executor profile definitions
│   │   ├── codex-executor.md    # Codex invocation guide
│   │   └── llm-gating.md       # LLM step gating rules
│   ├── craft/SKILL.md           # Base craft pipeline
│   ├── craft-ace/SKILL.md       # Local LLM implementer variant
│   ├── craft-duo/SKILL.md       # Codex co-executor variant
│   ├── craft-local/SKILL.md     # Local LLM review variant
│   ├── craft-squad/SKILL.md     # All three agents variant
│   ├── implement/SKILL.md
│   ├── finalize/SKILL.md
│   ├── architect/
│   │   ├── SKILL.md
│   │   └── architect-prompt.md
│   ├── develop/
│   │   ├── SKILL.md
│   │   ├── implementer-prompt.md
│   │   └── codex-prompt.md
│   ├── browser-test/
│   │   ├── SKILL.md
│   │   └── tester-prompt.md
│   ├── debug/SKILL.md
│   ├── simplify/SKILL.md
│   ├── reflect/SKILL.md
│   ├── llm-review/
│   │   ├── SKILL.md
│   │   └── dispatch-prompt.md
│   ├── graph-explore/
│   │   ├── SKILL.md
│   │   └── dispatch-prompt.md
│   └── bootstrap/SKILL.md
├── scripts/
│   ├── llm-config.sh            # Shared LLM defaults + llm_ensure_loaded()
│   ├── llm-implement.sh         # LLM implementation agent (write_file + STATUS)
│   ├── llm-agent.sh             # LLM exploration agent (read-only tools)
│   ├── llm-review.sh            # Single file review with thinking mode
│   ├── llm-analyze.sh           # Multi-file analysis
│   ├── llm-check.sh             # Availability check + auto-load
│   ├── llm-unload.sh            # Unload model from RAM
│   ├── codex-dispatch.sh        # Codex task dispatcher
│   ├── codex-status-schema.json # JSON schema for task status
│   ├── sync-agents-md.sh        # Generate AGENTS.md from CLAUDE.md
│   └── sync-check.sh            # Upstream sync verification
├── hooks/
│   ├── hooks.json               # SessionStart hook config
│   └── session-start            # Bootstrap injection script
├── references/
│   └── superpowers-sync.md      # Upstream sync tracking
├── prompts/
│   ├── frontend/
│   │   ├── migration-prompt.md  # Migrate frontend projects
│   │   └── new-project-prompt.md # Initialize new frontend projects
│   └── backend/
│       ├── migration-prompt.md  # Migrate backend projects
│       └── new-project-prompt.md # Initialize new backend projects
└── package.json
```

## Project Setup

craft-skills is designed to work with an optional parent-level CLAUDE.md that holds shared conventions, while each project keeps only project-specific configuration:

```
workspace/
├── .claude/
│   └── CLAUDE.md              # Shared: architecture rules, patterns, conventions
├── craft-skills/              # This plugin
├── project-a/
│   └── .claude/CLAUDE.md      # Project-specific: modules, routes, env vars
└── project-b/
    └── .claude/CLAUDE.md      # Project-specific: modules, routes, env vars
```

### Migrating an existing project

Use the appropriate migration prompt in a Claude Code session within the project:

- **Frontend**: Read `craft-skills/prompts/frontend/migration-prompt.md`
- **Backend**: Read `craft-skills/prompts/backend/migration-prompt.md`

Paste content as input — the agent analyzes the codebase and creates a project-specific CLAUDE.md.

### Setting up a new project

Use the appropriate new project prompt:

- **Frontend**: Read `craft-skills/prompts/frontend/new-project-prompt.md`
- **Backend**: Read `craft-skills/prompts/backend/new-project-prompt.md`

Paste content as input — the agent asks questions and scaffolds the configuration.

## Optional Integrations

craft-skills detects and uses these when available. Nothing breaks without them — steps are skipped automatically.

### Local LLM (via LM Studio)

Required by `craft-ace`, `craft-local`, and `craft-squad`. Optional for all other skills.

**Setup:**

1. Install [LM Studio](https://lmstudio.ai) and download `google/gemma-4-26b-a4b` (8-bit quantization)
2. Start the local server in LM Studio (Local Server → Start)

Scripts auto-detect LM Studio, load the model, and unload when done. All scripts source `llm-config.sh` for defaults. Override with env vars:

```bash
LLM_MODEL="your/model-id" LLM_URL="http://localhost:1234" /craft-ace
```

| Script | Purpose |
|---|---|
| `llm-config.sh` | Shared defaults (model, URL, context length) + `llm_ensure_loaded()` |
| `llm-implement.sh` | Implementation agent with `write_file` tool. Returns structured JSON status. |
| `llm-agent.sh` | Exploration agent with read-only file tools |
| `llm-review.sh` | Single file review with thinking mode |
| `llm-analyze.sh` | Multi-file analysis with thinking mode |
| `llm-check.sh` | Availability check + model auto-load |
| `llm-unload.sh` | Unload all models from RAM |

### Codex CLI (via OpenAI)

Required by `craft-duo` and `craft-squad`. Not used by other variants.

**Setup:**

```bash
npm i -g @openai/codex
codex login
```

Codex handles data-layer implementation tasks (types, services, queries, schemas) while Claude handles UI and integration. `AGENTS.md` is auto-generated from your `CLAUDE.md` so Codex inherits project conventions.

### Code review graph (via code-review-graph plugin)

Builds a structural knowledge graph of your codebase with Tree-sitter. Provides blast-radius analysis, semantic search, and import/export relationship queries.

**Setup:**

```bash
pip install code-review-graph
code-review-graph install
code-review-graph build
```

**Used in:**
- `craft` / `craft-ace` — codebase exploration during brainstorming
- `craft-ace` — reference file selection for Gemma (graph finds the best pattern-match files)
- `develop` — post-develop review (identifies high-risk changed files)

### UI/UX review (via ui-ux-pro-max skill)

Reviews spec UI sections — component layouts, interaction patterns, form design, error states, loading states, and accessibility — before implementation begins.

**Used in:** `craft` (spec review phase, step 1.8)

## Methodology

craft-skills absorbs proven workflows from [superpowers](https://github.com/obra/superpowers) and adds architecture-specific layers:

| From superpowers | Absorbed into | What was kept |
|---|---|---|
| brainstorming | craft | Business requirement exploration, one-question-at-a-time, 2-3 approaches |
| writing-plans | craft + architect | Bite-sized tasks, no placeholders, complete code in every step |
| subagent-driven-development | develop | Fresh agent per task, two-stage review |
| verification-before-completion | all skills | Iron law: no completion claims without evidence |
| systematic-debugging | debug | Four-phase investigation before fixing |

The `reflect evolve` mode checks the superpowers repo for useful upstream changes and proposes adaptations.

## Using with Different Stacks

craft-skills is stack-agnostic. The skills describe **process** (how to brainstorm, plan, develop, test, debug) — not technology. Your project's CLAUDE.md provides the technology context.

### Frontend (React, Next.js, Vue, etc.)

Use the frontend setup prompts:
```
Read craft-skills/prompts/frontend/migration-prompt.md
Read craft-skills/prompts/frontend/new-project-prompt.md
```

### Backend (Python, Go, Java, Node.js, etc.)

Use the backend setup prompts:
```
Read craft-skills/prompts/backend/migration-prompt.md
Read craft-skills/prompts/backend/new-project-prompt.md
```

### Any other project

Create a `.claude/CLAUDE.md` that describes your project's:
- Module/package structure and boundaries
- Development commands (build, test, lint)
- Architecture conventions and patterns
- Environment configuration

craft-skills reads your CLAUDE.md and adapts its workflows accordingly. No special configuration needed — just invoke `/craft`, `/implement`, or `/debug` as usual.

## Benchmarks

Real-world benchmark: implementing a complete domain (types, service, query hooks, UI component — 10 files) on a mid-size DDD project. Same feature, same plan, each variant in an isolated git worktree.

### Results

| Metric | craft | craft-ace | craft-duo | craft-squad |
|---|---|---|---|---|
| **Wall time** | 2m 36s | 16m 11s | 5m 42s | 7m 40s |
| **Files created** | 10 | 10 | 10 | 10 |
| **Fix iterations** | 1 | 2 | 0 | 0 |
| **Build pass** | Yes | Yes | Yes | Yes |
| **Data layer executor** | Claude Sonnet | Gemma (local) | Codex (GPT-5) | Codex (GPT-5) |
| **UI executor** | Claude Sonnet | Gemma + Sonnet fallback | Claude Sonnet | Claude Sonnet |
| **Review executor** | — | Gemma (local) | — | Gemma (local) |
| **Codex tasks** | — | — | 3/3 clean | 3/3 clean |
| **Gemma tasks** | — | 2/4 clean | — | review only |

### Observations

**craft (baseline):** Fastest overall. Claude Sonnet handled all tasks with only one import-order lint fix. Best choice when you want speed and simplicity with no external dependencies.

**craft-ace:** Gemma successfully implemented 2/4 tasks with zero errors (models + service). The other 2 needed minor fixes — a hallucinated type name in queries and an import ordering issue in UI. Wall time is longer due to LM Studio model loading (~2 min cold start) and sequential local inference. API cost savings: ~50% (4 of 6 tasks ran locally for free).

**craft-duo:** All 3 Codex dispatches succeeded (GPT-5 default model). Codex correctly read project conventions from AGENTS.md and produced clean code matching reference patterns. Zero fix iterations. Data layer ran on Codex while Claude handled UI — ~30% of implementation offloaded.

**craft-squad:** Same Codex success as duo, plus Gemma post-develop review. Gemma found 2 items, both false positives (a valid invalidation pattern and a style preference not used in the codebase). Adds review depth at the cost of ~2 min extra wall time.

### When to use what

| Situation | Recommended variant |
|---|---|
| Speed matters most | `craft` |
| Want to reduce API costs | `craft-ace` |
| Want to offload data layer | `craft-duo` |
| Maximum review coverage | `craft-squad` or `craft-local` |
| No external dependencies | `craft` |

> **Note:** Benchmarks represent a single run on one feature type (10-file domain). Results vary by feature complexity, model availability, and hardware. All variants include graceful fallback — if an external service is unavailable, tasks automatically fall back to Claude.

## License

MIT
