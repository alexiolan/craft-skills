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

| Skill | Who implements | Who reviews | Requirements |
|---|---|---|---|
| **craft** | Claude (Sonnet) | Claude (Opus/Sonnet) | None |
| **craft-ace** | Gemma (local LLM) | Gemma (review loops) | LM Studio |
| **craft-duo** | Claude + Codex (GPT-5) | Claude (Opus/Sonnet) | Codex CLI |
| **craft-local** | Claude (Sonnet) | Claude + Gemma | LM Studio |
| **craft-squad** | Claude + Codex (GPT-5) | Claude + Gemma | Codex CLI + LM Studio |

See [Choosing a Variant](#choosing-a-variant) in the Benchmarks section for detailed comparison with real performance data.

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

- "Add a reviews module" → triggers **craft** or **implement**
- "The API returns 500 after saving" → triggers **debug**
- "Audit the Claude configs" → triggers **reflect**

### Manual invocation

```
/craft Add a notification preferences page
/craft-ace Build a reporting dashboard
/implement 15
/debug The API returns 500 on save
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
│   ├── superpowers-sync.md      # Upstream sync tracking
│   ├── form-field-patterns.md   # TanStack Form + Zod reference
│   ├── daisyui-portal-patterns.md # Portal/overflow solutions
│   └── vitest-setup.md          # Test setup reference
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

Codex handles data-layer implementation tasks (types, services, queries, schemas) while Claude handles UI and integration. Uses your account's default model (GPT-5 with ChatGPT auth, or specify `codex-mini`/`gpt-5-codex` with API key auth). `AGENTS.md` is auto-generated from your `CLAUDE.md` so Codex inherits project conventions.

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

### Delegation Ratio

The benchmark feature produces 170 lines of code across 10 files. Here's how the work is distributed across executors:

| Task | LOC | craft | craft-ace | craft-duo | craft-squad |
|---|---|---|---|---|---|
| Models (types) | 28 | Claude | Gemma | Codex | Codex |
| Service (API layer) | 28 | Claude | Gemma | Codex | Codex |
| Queries (data hooks) | 36 | Claude | Gemma | Codex | Codex |
| Barrel exports | 4 | Claude | Claude | Claude | Claude |
| UI component | 74 | Claude | Gemma | Claude | Claude |
| **Claude LOC** | | **170 (100%)** | **4 (2%)** | **78 (46%)** | **78 (46%)** |
| **Delegated LOC** | | **0** | **166 (98%)** | **92 (54%)** | **92 (54%)** |

**Claude API tokens (orchestrator):**

| | craft | craft-ace | craft-duo | craft-squad |
|---|---|---|---|---|
| **Tokens** | 24,606 | 38,572 | 61,779 | 45,137 |
| **Of which: implementation** | ~24K | ~4K | ~30K | ~25K |
| **Of which: orchestration overhead** | ~1K | ~35K | ~32K | ~20K |

> Orchestration overhead includes: reading reference files, writing dispatch prompts, parsing JSON output, running verification. This overhead is the "cost" of delegation — ace/duo/squad spend Claude tokens coordinating external executors instead of writing code directly.

**Net Claude token economy vs baseline:**

| Variant | Claude implementation tokens | Savings vs craft | Quality |
|---|---|---|---|
| **craft** | ~24K (baseline) | — | 1 fix iteration |
| **craft-ace** | ~4K | **~83% fewer** | 2 fix iterations (minor) |
| **craft-duo** | ~30K | **~0% fewer*** | 0 fix iterations |
| **craft-squad** | ~25K | **~0% fewer*** | 0 fix iterations + review |

*\* craft-duo and craft-squad use MORE total Claude tokens than baseline due to orchestration overhead (Codex prompt generation, AGENTS.md sync, JSON parsing). The savings come from Codex/OpenAI tokens being cheaper than Claude tokens, and from parallelization potential on larger features.*

### Observations

**craft (baseline):** Fastest and most token-efficient. Claude generates everything in one pass. Best for speed and simplicity.

**craft-ace:** Biggest Claude API savings — Gemma handles 98% of code generation locally for free. Claude only writes trivial barrel exports and orchestrates. Trade-off: 6x slower wall time (local inference) and 2 minor fixes needed. Best for cost-conscious development.

**craft-duo:** Codex (GPT-5) handled data layer perfectly — 3/3 dispatches clean with zero fixes. But orchestration overhead means total Claude tokens are comparable to baseline. The real benefit is on larger features where Codex tasks run in parallel with Claude UI tasks, reducing wall time.

**craft-squad:** Combines Codex implementation + Gemma review. Gemma's review found only false positives on this feature. Most valuable on complex features where an independent review catches real issues.

### Choosing a Variant

| Variant | Best for | Trade-offs | Requirements |
|---|---|---|---|
| **craft** | Day-to-day development. Fast iteration, quick features, bug fixes. You want the simplest and most reliable path. | Fastest (2-3 min). All tokens go to Claude — no delegation overhead, no external dependencies to break. Slight quality variance (1 fix iteration typical). | None |
| **craft-ace** | Cost-conscious development. You're building multiple features and want to minimize Claude API spend. Good for data-heavy domains with lots of types/services. | Biggest savings (~83% fewer Claude implementation tokens). Gemma handles 98% of code generation locally for free. Trade-off: 6x slower wall time due to local inference, and occasional minor fixes needed (hallucinated names, import ordering). | LM Studio + Gemma model |
| **craft-duo** | Large features where parallelism matters. Codex runs data-layer tasks while Claude handles UI simultaneously. Best when you have 10+ tasks and want wall-time reduction. | Codex produces clean code (0 fix iterations), but orchestration overhead means no Claude token savings on small features. Real benefit appears at scale. | Codex CLI |
| **craft-local** | Deeper review without changing who implements. Same as craft, but with Gemma reviewing specs, plans, and post-develop code. Good when stakes are high. | Adds ~30% wall time for review passes. No cost savings — quality investment. | LM Studio + Gemma model |
| **craft-squad** | Maximum coverage on critical features. All three AIs contribute: Codex implements data layer, Claude handles UI, Gemma reviews everything. | Most thorough but slowest (7-8 min). Gemma review may produce false positives on simple features — more valuable on complex ones. | Codex CLI + LM Studio |

**Decision flowchart:**

```
Need to build something?
  → Is it a quick fix or small feature?     → craft
  → Is it a large feature?
      → Do you have LM Studio?
          → Want to save money?              → craft-ace
          → Want deeper review?              → craft-local
      → Do you have Codex CLI?
          → Want parallel execution?         → craft-duo
      → Have both?
          → High stakes, want everything?    → craft-squad
  → Not sure?                                → craft (always works)
```

> **Note:** Benchmarks represent a single run on one feature type (10-file domain with 170 LOC). Results vary by feature complexity — larger features with more data-layer tasks show greater delegation benefits. All variants include graceful fallback — if an external service is unavailable, tasks automatically fall back to Claude.

## License

MIT
