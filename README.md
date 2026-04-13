# craft-skills

A [Claude Code](https://claude.ai/code) plugin providing DDD-first frontend development skills for Next.js projects.

Replaces generic AI workflows with battle-tested, domain-driven processes: collaborative brainstorming, parallel agent development, browser testing, systematic debugging, and self-improvement.

## Installation

### From GitHub marketplace

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

### Updating in consuming projects

Due to a [known Claude Code bug](https://github.com/anthropics/claude-code/issues/37252), `plugin update` doesn't fetch the latest version automatically. Run this to update:

```bash
git -C ~/.claude/plugins/marketplaces/craft-skills pull --ff-only && claude plugin update craft-skills@craft-skills --scope project
```

## Skills

### Pipeline Skills

| Skill | Description |
|---|---|
| **craft** | Full pipeline: brainstorm → plan → develop → test. Claude only, no external deps. |
| **craft-ace** | Craft with local Gemma as implementer + reviewer. Opus orchestrates, Sonnet fallback. ~45-60% cost savings. Requires LM Studio. |
| **craft-duo** | Craft with Codex as co-executor for data-layer tasks. Requires Codex CLI. |
| **craft-local** | Craft with LM Studio LLM reviews. Deeper review, no implementation delegation. Requires LM Studio. |
| **craft-squad** | Craft with Claude + Codex + LM Studio. Power-user mode, all three agents. |
| **implement** | Fast pipeline: architect → develop → test. For clear, well-understood requirements. |
| **finalize** | Post-plan pipeline: develop → test. Use when a plan already exists. |

### Process Skills

| Skill | Description |
|---|---|
| **architect** | Analyze requirements and create a detailed implementation plan. No code written. |
| **develop** | Execute an approved plan using parallel frontend-developer agents with shared state coordination. |
| **browser-test** | Plan and run parallel browser-based UI tests using multiple agents. |
| **debug** | Systematic root-cause investigation before attempting any fix. |
| **simplify** | Review changed code for reuse opportunities, quality, and DDD compliance. |
| **reflect** | Self-improvement: audit project configs, maintain skill health, sync upstream, auto-dream. |
| **llm-review** | Run a local LLM review on files. Auto-loads/unloads model. Free second opinion with thinking mode. |

### System Skills

| Skill | Description |
|---|---|
| **bootstrap** | Loaded at SessionStart. Establishes skill awareness and auto-trigger rules. |

## How It Works

### Automatic triggering

The bootstrap skill loads at every session start and watches for trigger conditions. When you describe a task, the relevant skill is invoked automatically:

- "Add a reviews domain" → triggers **craft** or **implement**
- "The toast doesn't show after saving" → triggers **debug**
- "Audit the Claude configs" → triggers **reflect**

### Manual invocation

Use slash commands directly:

```
/craft Add a notification preferences page
/implement 15
/debug The form validation isn't working
/reflect project
```

### Input types

Pipeline skills accept three input formats:

- **Prompt file number**: `/craft 15` reads `.claude/prompts/15-*.md`
- **Direct text**: `/implement Add a logout button`
- **Empty**: auto-detects recent plans or asks for input

## Architecture

```
craft-skills/
├── .claude-plugin/
│   ├── plugin.json          # Plugin manifest
│   └── marketplace.json     # GitHub marketplace definition
├── skills/
│   ├── bootstrap/SKILL.md
│   ├── craft/SKILL.md
│   ├── craft-ace/SKILL.md         # Local LLM implementer variant
│   ├── craft-duo/SKILL.md         # Codex co-executor variant
│   ├── craft-local/SKILL.md       # Local LLM review variant
│   ├── craft-squad/SKILL.md       # All three agents variant
│   ├── _craft-core/               # Shared profile definitions
│   │   └── profiles.md
│   ├── implement/SKILL.md
│   ├── finalize/SKILL.md
│   ├── architect/
│   │   ├── SKILL.md
│   │   └── architect-prompt.md    # Implementation architect agent prompt
│   ├── develop/
│   │   ├── SKILL.md
│   │   ├── implementer-prompt.md  # Frontend developer agent prompt
│   │   └── codex-prompt.md        # Codex task prompt template
│   ├── browser-test/
│   │   ├── SKILL.md
│   │   └── tester-prompt.md       # Browser tester agent prompt
│   ├── reflect/SKILL.md
│   ├── debug/SKILL.md
│   ├── simplify/SKILL.md
│   └── llm-review/SKILL.md
├── hooks/
│   ├── hooks.json           # SessionStart hook config
│   └── session-start        # Bootstrap injection script
├── references/
│   └── superpowers-sync.md  # Upstream sync tracking
├── migration-prompt.md      # Prompt for migrating existing projects
├── new-project-prompt.md    # Prompt for initializing new projects
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

craft-skills detects and uses these plugins when available. Nothing breaks without them — steps are skipped automatically.

### Local LLM (via LM Studio)

Gemma 4 26B A4B (8-bit) running locally. Used for two purposes depending on which craft variant you choose:

- **`craft-local`** — Reviews only (spec, plan, post-develop). Free second opinion from a different model architecture.
- **`craft-ace`** — Reviews AND implementation. Gemma writes code with `write_file` tool, following project patterns from reference files. ~45-60% API cost reduction.

**Setup:**

1. Install [LM Studio](https://lmstudio.ai) and download `google/gemma-4-26b-a4b` (8-bit)
2. Start the local server in LM Studio (Local Server → Start)

**Scripts included:**

| Script | Purpose |
|---|---|
| `llm-config.sh` | Shared defaults (model, URL, context length) + `llm_ensure_loaded()` function |
| `llm-implement.sh` | **Implementation agent** — writes files via `write_file` tool, returns structured JSON status. Used by `craft-ace`. |
| `llm-agent.sh` | Autonomous exploration agent with file access tools |
| `llm-review.sh` | Reviews a single file with thinking mode |
| `llm-analyze.sh` | Analyzes multiple files together |
| `llm-check.sh` | Checks availability, auto-loads model |
| `llm-unload.sh` | Unloads model from RAM |

All scripts source `llm-config.sh` for model defaults. Override with env vars: `LLM_MODEL`, `LLM_URL`, `LLM_CONTEXT_LENGTH`.

**Used in:** `craft-ace` (implementation + reviews), `craft-local` (reviews only), `craft-squad` (reviews only), `develop` (post-develop review), `debug` (data flow tracing). Can also be invoked directly: `/llm-review path/to/file.ts "focus area"`

### Code review graph (via code-review-graph plugin)

Builds a structural map of your codebase with Tree-sitter, tracks changes incrementally, and provides blast-radius analysis so Claude reads only the files that matter. Up to 8x token reduction on reviews.

**Setup:**

```bash
pip install code-review-graph
code-review-graph install
code-review-graph build
```

**Used in:** `develop` (post-develop review — identifies high-risk files for targeted review)

### UI/UX review (via ui-ux-pro-max skill)

Reviews spec UI sections — component layouts, interaction patterns, form design, error states, loading states, and accessibility — before implementation begins.

**Used in:** `craft` (spec review phase, step 1.8)

## Methodology

craft-skills absorbs proven workflows from [superpowers](https://github.com/obra/superpowers) (v5.0.6) and adds DDD-specific layers:

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
