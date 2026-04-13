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

## Quick Start

Once installed, craft-skills activates automatically. Just describe what you want to build:

```
/craft Add a user notifications system
```

**What happens:**

1. **Brainstorm** — Claude explores your codebase, asks clarifying questions one at a time, proposes 2-3 approaches, and collaborates with you on a design
2. **Plan** — Creates a detailed implementation plan with exact file paths, task ordering, and parallel/sequential dependencies
3. **Develop** — Dispatches parallel developer agents, each implementing one task. Agents share state and coordinate via a shared-state file
4. **Test** — Runs browser tests against the implemented feature
5. **Report** — Summarizes what was built, decisions made, and any open items

You approve or redirect at every phase — nothing runs without your sign-off.

**Other entry points:**

```
/implement Add a logout button          # Skip brainstorm, go straight to plan → develop
/architect 03                            # Plan only (reads .claude/prompts/03-*.md)
/debug The API returns 500 on save       # Investigate before fixing — no guessing
/simplify                                # Review recent changes for quality
/reflect project                         # Audit your Claude configs
```

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

See [Choosing a Variant](#choosing-a-variant) for detailed comparison with real benchmark data.

### Shortcut Skills

| Skill | Description |
|---|---|
| **implement** | Fast pipeline: architect → develop → test. For clear, well-understood requirements. |
| **finalize** | Post-plan pipeline: develop → test. Use when a plan already exists. |
| **architect** | Create an implementation plan. No code written. |
| **develop** | Execute an approved plan using parallel agents. |
| **browser-test** | Run parallel browser-based UI tests. |

### Process Skills

| Skill | Description |
|---|---|
| **debug** | Systematic root-cause investigation before attempting any fix. |
| **simplify** | Review changed code for reuse opportunities and architecture compliance. |
| **reflect** | Audit project configs, maintain skill health, sync upstream. |

## Getting Started

### 1. Set up your project's CLAUDE.md

craft-skills reads your project's `CLAUDE.md` to understand your tech stack, architecture, and conventions. Use the setup prompts to generate one:

**Frontend project:**
```
Read craft-skills/prompts/frontend/migration-prompt.md
```

**Backend project:**
```
Read craft-skills/prompts/backend/migration-prompt.md
```

**New project:**
```
Read craft-skills/prompts/frontend/new-project-prompt.md
Read craft-skills/prompts/backend/new-project-prompt.md
```

**Any other project** — create `.claude/CLAUDE.md` manually describing your:
- Module/package structure and boundaries
- Development commands (build, test, lint)
- Architecture conventions and patterns
- Environment configuration

### 2. Optional: parent CLAUDE.md for multi-project workspaces

If you have multiple projects sharing conventions, put shared rules in a parent CLAUDE.md:

```
workspace/
├── .claude/
│   └── CLAUDE.md              # Shared: architecture rules, patterns, conventions
├── project-a/
│   └── .claude/CLAUDE.md      # Project-specific: modules, routes, env vars
└── project-b/
    └── .claude/CLAUDE.md      # Project-specific: modules, routes, env vars
```

### 3. Start building

```
/craft Add a pricing calculator
```

That's it. The skills handle the rest — reading your CLAUDE.md, exploring your codebase, coordinating agents, and verifying the output.

## Optional Integrations

craft-skills detects and uses these when available. Nothing breaks without them — steps are skipped automatically.

### Local LLM (via LM Studio)

Required by `craft-ace`, `craft-local`, and `craft-squad`.

1. Install [LM Studio](https://lmstudio.ai) and download `google/gemma-4-26b-a4b` (8-bit quantization)
2. Start the local server (Local Server → Start)

Scripts auto-detect LM Studio, load the model, and unload when done. Override defaults with env vars:

```bash
LLM_MODEL="your/model-id" LLM_URL="http://localhost:1234" /craft-ace
```

### Codex CLI (via OpenAI)

Required by `craft-duo` and `craft-squad`.

```bash
npm i -g @openai/codex
codex login
```

Codex handles data-layer tasks (types, services, queries) while Claude handles UI and integration. Uses your account's default model (GPT-5 with ChatGPT auth, or specify `codex-mini`/`gpt-5-codex` with API key auth). `AGENTS.md` is auto-generated from your `CLAUDE.md` so Codex inherits project conventions.

### Code review graph

Builds a structural knowledge graph of your codebase with Tree-sitter. Provides blast-radius analysis, semantic search, and dependency queries.

```bash
pip install code-review-graph
code-review-graph install
code-review-graph build
```

### UI/UX review (via ui-ux-pro-max skill)

Reviews UI components for layout quality, interaction patterns, loading/error states, accessibility, and design system consistency. Activates conditionally — only when the project has UI components (`.tsx`, `.vue`, `.svelte` files or a UI framework in CLAUDE.md).

**Used in:**
- `craft` — spec UI review (step 1.8)
- `architect` — plan UI architecture review (step 2)
- `develop` — post-develop UI component review (step 3.5)
- `simplify` — UI anti-pattern detection in changed files

## Benchmarks

Real-world benchmark: implementing a complete module (types, service, query hooks, UI component — 10 files, 170 LOC) on a mid-size project. Same feature, same plan, each variant in an isolated git worktree.

### Results

| Metric | craft | craft-ace | craft-duo | craft-squad |
|---|---|---|---|---|
| **Wall time** | 2m 36s | 16m 11s | 5m 42s | 7m 40s |
| **Files created** | 10 | 10 | 10 | 10 |
| **Fix iterations** | 1 | 2 | 0 | 0 |
| **Build pass** | Yes | Yes | Yes | Yes |
| **Data layer executor** | Claude Sonnet | Gemma (local) | Codex (GPT-5) | Codex (GPT-5) |
| **UI executor** | Claude Sonnet | Gemma + Sonnet fallback | Claude Sonnet | Claude Sonnet |
| **Codex tasks** | — | — | 3/3 clean | 3/3 clean |
| **Gemma tasks** | — | 2/4 clean | — | review only |

### Delegation Ratio

How the 170 lines of code are distributed across executors:

| Task | LOC | craft | craft-ace | craft-duo | craft-squad |
|---|---|---|---|---|---|
| Models (types) | 28 | Claude | Gemma | Codex | Codex |
| Service (API layer) | 28 | Claude | Gemma | Codex | Codex |
| Queries (data hooks) | 36 | Claude | Gemma | Codex | Codex |
| Barrel exports | 4 | Claude | Claude | Claude | Claude |
| UI component | 74 | Claude | Gemma | Claude | Claude |
| **Claude LOC** | | **170 (100%)** | **4 (2%)** | **78 (46%)** | **78 (46%)** |
| **Delegated LOC** | | **0** | **166 (98%)** | **92 (54%)** | **92 (54%)** |

### Claude Token Economy

| | craft | craft-ace | craft-duo | craft-squad |
|---|---|---|---|---|
| **Total Claude tokens** | 24,606 | 38,572 | 61,779 | 45,137 |
| **Implementation tokens** | ~24K | ~4K | ~30K | ~25K |
| **Orchestration overhead** | ~1K | ~35K | ~32K | ~20K |

| Variant | Claude implementation savings | Quality |
|---|---|---|
| **craft** | Baseline | 1 fix iteration |
| **craft-ace** | **~83% fewer** | 2 fix iterations (minor) |
| **craft-duo** | ~0%* | 0 fix iterations |
| **craft-squad** | ~0%* | 0 fix iterations + review |

*\* duo/squad use more total Claude tokens due to orchestration overhead. The savings come from Codex tokens being cheaper and from parallelization on larger features.*

### How craft-ace Achieves 83% Savings

`craft-ace` offloads implementation and reviews to a local LLM (Gemma 4 26B), keeping Claude for orchestration only:

| Role | Model | Cost |
|---|---|---|
| Orchestrator, brainstorm, integration | Claude Opus | Paid |
| Spec and plan reviews (up to 4 rounds) | Gemma | Free |
| Data layer implementation | Gemma | Free |
| UI component implementation | Gemma first, Sonnet fallback | Mostly free |
| Post-develop review | Gemma | Free |

**How it works:** The orchestrator selects reference files from the codebase (via knowledge graph or glob), `llm-implement.sh` sends the task + references to Gemma, Gemma writes files using a scope-restricted `write_file` tool, and returns structured JSON status. If Gemma fails, Sonnet takes over with Gemma's attempt as context.

**Trade-off:** ~6x slower wall time (local inference + model cold start) and occasional minor fixes needed (hallucinated names, import ordering). Best for cost-conscious development across multiple features.

### Choosing a Variant

| Variant | Best for | Trade-offs | Requirements |
|---|---|---|---|
| **craft** | Day-to-day development. Fast iteration, quick features, bug fixes. Simplest and most reliable. | Fastest (2-3 min). No external dependencies. Slight quality variance (1 fix iteration typical). | None |
| **craft-ace** | Cost-conscious development. Multiple features, data-heavy work. | ~83% fewer Claude tokens. 6x slower wall time. Occasional minor fixes. | LM Studio + Gemma |
| **craft-duo** | Large features where parallelism matters. 10+ tasks, want wall-time reduction. | Codex produces clean code, but orchestration overhead offsets token savings on small features. | Codex CLI |
| **craft-local** | High-stakes features. Same as craft + Gemma reviewing specs, plans, and code. | +30% wall time for review passes. No cost savings — quality investment. | LM Studio + Gemma |
| **craft-squad** | Maximum coverage on critical features. All three AIs contribute. | Most thorough but slowest. Gemma review may flag false positives on simple features. | Codex CLI + LM Studio |

**Decision flowchart:**

```
Need to build something?
  → Quick fix or small feature?              → craft
  → Large feature?
      → Have LM Studio?
          → Want to save money?              → craft-ace
          → Want deeper review?              → craft-local
      → Have Codex CLI?
          → Want parallel execution?         → craft-duo
      → Have both? High stakes?              → craft-squad
  → Not sure?                                → craft (always works)
```

> Benchmarks represent a single run on one feature type. Results vary by feature complexity — larger features with more data-layer tasks show greater delegation benefits. All variants include graceful fallback: if an external service is unavailable, tasks automatically fall back to Claude.

## Architecture

<details>
<summary>Directory structure (click to expand)</summary>

```
craft-skills/
├── skills/
│   ├── _craft-core/             # Shared pipeline logic (profiles, gating, executors)
│   ├── craft/SKILL.md           # Base craft pipeline
│   ├── craft-ace/SKILL.md       # Local LLM implementer variant
│   ├── craft-duo/SKILL.md       # Codex co-executor variant
│   ├── craft-local/SKILL.md     # Local LLM review variant
│   ├── craft-squad/SKILL.md     # All three agents variant
│   ├── implement/SKILL.md       # Fast pipeline (architect → develop → test)
│   ├── finalize/SKILL.md        # Post-plan pipeline (develop → test)
│   ├── architect/               # Planning (SKILL.md + architect-prompt.md)
│   ├── develop/                 # Execution (SKILL.md + implementer-prompt.md + codex-prompt.md)
│   ├── browser-test/            # Testing (SKILL.md + tester-prompt.md)
│   ├── debug/SKILL.md
│   ├── simplify/SKILL.md
│   ├── reflect/SKILL.md
│   ├── llm-review/              # Local LLM review reference
│   ├── graph-explore/           # Knowledge graph reference
│   └── bootstrap/SKILL.md       # SessionStart auto-trigger
├── scripts/                     # LLM and Codex dispatch scripts
├── hooks/                       # SessionStart hook
├── prompts/
│   ├── frontend/                # Frontend migration + setup prompts
│   └── backend/                 # Backend migration + setup prompts
├── references/                  # Tech-specific reference docs
└── package.json
```

</details>

### Methodology

craft-skills absorbs proven workflows from [superpowers](https://github.com/obra/superpowers):

| From superpowers | Used in | What was kept |
|---|---|---|
| brainstorming | craft | One-question-at-a-time, 2-3 approaches, incremental validation |
| writing-plans | craft + architect | Bite-sized tasks, no placeholders, complete code in every step |
| subagent-driven-development | develop | Fresh agent per task, two-stage review |
| verification-before-completion | all skills | No completion claims without evidence |
| systematic-debugging | debug | Four-phase investigation before fixing |

The `reflect evolve` mode checks the superpowers repo for useful upstream changes and proposes adaptations.

## License

MIT
