---
name: reflect
description: "Use when auditing, improving, or maintaining Claude configuration, skills, and project health. Supports modes: full sweep, project health, skill health, evolution (upstream sync + auto-dream), and cleanup. Invoke periodically or when the user asks to audit or improve configs."
---

# Reflect

Comprehensive self-improvement: audit project configs, maintain skill health, sync upstream, generate enhancements, clean up.

## Input

The user input is: `$ARGUMENTS`

### Mode Detection

- **Empty or `full`**: Run all phases (full sweep)
- **`project`**: Phase 1 only (project health audit)
- **`skills`**: Phase 2 only (craft-skills package health)
- **`evolve`**: Phase 3 only (upstream sync + auto-dream)
- **`cleanup`**: Phase 4 only (housekeeping)

## Phase 1: Project Health

Audit the current project's Claude configuration against reality.

### 1.1 CLAUDE.md Accuracy

Read the project's CLAUDE.md and verify against the actual codebase:

- **Domain list**: Does the business domains list match what exists in `src/domain/`? Use Glob to check.
- **File paths**: Do referenced paths (shared components, config files) actually exist?
- **Patterns**: Do described patterns (query factories, service layer, form fields) match current implementations?
- **Shared components/hooks**: Are listed components and hooks still accurate?

### 1.2 Parent vs Project CLAUDE.md

Check content is at the correct level:
- Is there generic content in the project CLAUDE.md that belongs in the parent?
- Is there project-specific content in the parent CLAUDE.md?
- Are there rules duplicated between both files?

### 1.3 Memory Hygiene

Read all memory files in the project's memory directory:
- Flag stale entries (reference removed features, old patterns)
- Flag duplicates
- Flag entries that conflict with current codebase state

### 1.4 Settings Audit

Read `settings.json` and `settings.local.json`:
- Are all referenced plugins still installed and relevant?
- Are there permissions for tools/commands no longer used?

### 1.5 Plans & Prompts Cleanup

For each plan in `.claude/plans/`:
1. Check if the feature has been implemented (search codebase)
2. Categorize: Completed, Partially completed, Not started, Stale
3. Propose archiving completed plans to `.claude/plans/archive/`

For each prompt in `.claude/prompts/`:
1. Check if the feature has been implemented
2. If implemented, propose archiving

## Phase 2: Skill Health

Audit the craft-skills package itself.

### 2.1 Internal Consistency

Read all SKILL.md files and check:
- All follow the same frontmatter format (name, description)
- Description starts with "Use when..." (per agentskills.io spec)
- No broken cross-skill references (if craft says "invoke develop", does develop exist?)

### 2.2 Prompt Freshness

Read all agent prompt files (*-prompt.md):
- Do they reference patterns that still exist in the parent CLAUDE.md?
- Are they consistent with each other?

### 2.3 Gap Analysis

Read memory files across all projects under the parent `frontend/` directory:
- Are there feedback memories that repeat across projects? → Should be a skill rule
- Are there recurring manual workflows? → Candidate for a new skill
- Are there skills that get skipped often? → May need trigger condition tuning

## Phase 3: Evolution

### 3a: Superpowers Upstream Sync

1. Fetch `https://raw.githubusercontent.com/obra/superpowers/main/CHANGELOG.md`
2. Read `references/superpowers-sync.md` for last checked version
3. If new version detected:
   - Fetch changed SKILL.md files from the repository
   - For each change: evaluate if it improves our workflow
   - Draft adaptations (translate to our DDD context, don't copy-paste)
   - Present proposals to user for approval
4. Update `references/superpowers-sync.md` with new version and decisions

### 3b: Claude Code Awareness

Check if there are new Claude Code tools, capabilities, or patterns:
- New tool types available?
- New agent capabilities?
- Suggest skill adaptations if relevant

### 3c: Auto-Dream

Dispatch an agent to perform deep analysis:
1. Read all project memory files across `frontend/` projects
2. Analyze recent git history across projects (last 2 weeks)
3. Identify patterns:
   - Repeated feedback → should become a skill rule
   - Recurring manual tasks → automation candidate
   - Skills producing poor results → need refinement
   - Common architectural patterns emerging → should be documented
4. Generate enhancement proposals ranked by impact
5. Present to user for approval

## Phase 4: Cleanup

### 4.1 Auto-Fix (low risk, verifiable)

These are applied automatically:
- Update domain lists in CLAUDE.md to match `src/domain/`
- Fix stale file paths in CLAUDE.md
- Archive completed plans to `.claude/plans/archive/`

### 4.2 Ask First (subjective or significant)

These are presented for approval:
- Removing stale memory entries
- Modifying skill content
- Moving content between parent/project CLAUDE.md
- Suggesting new skills

## Presenting Findings

For each issue found, present:
- **What's wrong**: The specific inconsistency
- **Where**: Which file(s) are affected
- **Proposed fix**: The concrete change
- **Impact**: How this affects behavior

Categorize as:
- **Critical** — causes errors, broken paths, missing principles
- **Incorrect** — factually wrong, will cause confusion
- **Stale** — outdated references
- **Duplication** — rules repeated across levels
- **Cleanup** — plans/prompts/memory that can be archived
- **Improvement** — opportunities to enhance effectiveness

Wait for user approval before making changes (except auto-fix tier).
