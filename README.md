# craft-skills

A [Claude Code](https://claude.ai/code) plugin providing DDD-first frontend development skills for Next.js projects.

Replaces generic AI workflows with battle-tested, domain-driven processes: collaborative brainstorming, parallel agent development, browser testing, systematic debugging, and self-improvement.

## Installation

```
/plugin marketplace add alexiolan/craft-skills
/plugin install craft-skills@craft-skills
```

### Local development

```bash
claude --plugin-dir /path/to/craft-skills
```

Use `/reload-plugins` during a session to pick up changes without restarting.

### Setup after cloning

Configure git to use the project's hooks directory for automatic version bumping on each commit:

```bash
git config core.hooksPath .githooks
```

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
| **simplify** | Review changed code for reuse opportunities, quality, and DDD compliance. |
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
- "The toast doesn't show after saving" → triggers **debug**
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
├── migration-prompt.md          # Prompt for migrating existing projects
├── new-project-prompt.md        # Prompt for initializing new projects
└── package.json
```

## Project Setup

craft-skills is designed to work with a parent-level CLAUDE.md that holds generic DDD/Next.js conventions, while each project keeps only project-specific configuration:

```
frontend/
├── .claude/
│   └── CLAUDE.md              # Shared: DDD rules, patterns, form conventions
├── craft-skills/              # This plugin
├── project-a/
│   └── .claude/CLAUDE.md      # Project-specific: domains, routes, env vars
└── project-b/
    └── .claude/CLAUDE.md      # Project-specific: domains, routes, env vars
```

### Migrating an existing project

Use the migration prompt in a Claude Code session within the project:

1. Read `craft-skills/migration-prompt.md`
2. Paste content as input — the agent analyzes the codebase and creates a project-specific CLAUDE.md

### Setting up a new project

Use the new project prompt:

1. Read `craft-skills/new-project-prompt.md`
2. Paste content as input — the agent asks questions and scaffolds the configuration

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

craft-skills absorbs proven workflows from [superpowers](https://github.com/obra/superpowers) and adds DDD-specific layers:

| From superpowers | Absorbed into | What was kept |
|---|---|---|
| brainstorming | craft | Business requirement exploration, one-question-at-a-time, 2-3 approaches |
| writing-plans | craft + architect | Bite-sized tasks, no placeholders, complete code in every step |
| subagent-driven-development | develop | Fresh agent per task, two-stage review |
| verification-before-completion | all skills | Iron law: no completion claims without evidence |
| systematic-debugging | debug | Four-phase investigation before fixing |

The `reflect evolve` mode checks the superpowers repo for useful upstream changes and proposes adaptations.

## License

MIT
