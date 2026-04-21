---
name: reflect
description: "Use when auditing, improving, or maintaining project health — CLAUDE.md accuracy, memory hygiene, settings, plans, and pattern discovery. Invoke periodically or when the user asks to audit or improve their project configuration."
---

# Reflect

Project self-improvement: audit configs against reality, discover patterns worth documenting, clean up stale artifacts.

## Input

The user input is: `$ARGUMENTS`

### Mode Detection

- **Empty or `full`**: Run all phases
- **`health`**: Phase 1 only (project health audit)
- **`evolve`**: Phase 2 only (pattern discovery + CLAUDE.md evolution)
- **`cleanup`**: Phase 3 only (housekeeping)

## Phase 1: Project Health

Audit the current project's Claude configuration against reality.

### 1.1 CLAUDE.md Accuracy

Read the project's CLAUDE.md and verify against the actual codebase:

- **Module list**: Does the listed module/domain structure match what actually exists?
- **File paths**: Do referenced paths (shared components, config files) actually exist?
- **Patterns**: Do described patterns (query factories, service layer, form fields) match current implementations?
- **Shared components/hooks**: Are listed components and hooks still accurate?
- **Outdated rules**: Are there rules referencing libraries, tools, or conventions no longer in use?

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

### 1.5 Plans & Prompts

For each plan in `.claude/plans/`:
1. Check if the feature has been implemented (search codebase)
2. Categorize: Completed, Partially completed, Not started, Stale
3. Propose archiving completed plans to `.claude/plans/archive/`

For each prompt in `.claude/prompts/`:
1. Check if the feature has been implemented
2. If implemented, propose archiving

### 1.6 Project Contracts Freshness

Audit the one-time, project-level contract files that downstream craft-skills consume. Each has the same lifecycle: generated once per project, hand-editable, needs occasional refresh when the underlying reality changes.

**`.claude/aesthetic-direction.md`:**
- If missing: suggest running `craft-skills:aesthetic-direction` once (only relevant for projects with a UI).
- If present and older than 180 days: ask whether the design system has changed since; offer regeneration.

**`.claude/reuse-index.md`:**
- If missing: suggest running `craft-skills:reuse-index` once. Without it, every planning session falls back to ad-hoc grep.
- If present and older than 60 days: compare entries against the current shared directory. If >5 top-level shared files exist whose exports aren't in the index, flag it as stale and suggest `craft-skills:reuse-index --force`.
- If the index's "What NOT to duplicate" section has hand-edited entries, preserve them across regeneration — call this out when suggesting a refresh.

**`CLAUDE.md` (parent + project):** already covered by 1.1 and 1.2 above.

Freshness is advisory, not enforced — `reflect` only suggests, the human decides.

## Phase 2: Evolve

Discover patterns in how you work and propose improvements to project configuration.

### 2.1 Pattern Discovery

Dispatch an agent to perform analysis of the current project:

1. Read all memory files in the project's memory directory
2. Analyze recent git history (last 2 weeks)
3. Identify patterns:
   - **Repeated feedback** → should become a rule in CLAUDE.md
   - **Recurring manual tasks** → worth documenting as a workflow in CLAUDE.md
   - **Common architectural patterns emerging** → should be documented in CLAUDE.md
   - **Frequent mistakes or corrections** → add guard rules to CLAUDE.md
4. Generate proposals ranked by impact
5. Present to user for approval

### 2.2 Cross-Project Insights

If the project has a parent CLAUDE.md (monorepo or workspace):

1. Read memory files from sibling projects under the same parent directory
2. Look for patterns that repeat across projects:
   - Same feedback given in multiple projects → belongs in parent CLAUDE.md
   - Same workarounds applied → should be a shared rule
   - Conventions that emerged independently → formalize in parent CLAUDE.md
3. Propose updates to the parent CLAUDE.md (never to sibling project files)

### 2.3 CLAUDE.md Completeness

Compare what's documented vs what the codebase actually does:
- Are there undocumented conventions the code follows consistently?
- Are there utility functions/hooks widely used but not mentioned?
- Are there testing patterns or data-fetching patterns worth documenting?

Propose additions to CLAUDE.md for anything that would help Claude work more effectively in this project.

## Phase 3: Cleanup

### 3.1 Auto-Fix (low risk, verifiable)

Applied automatically:
- Update domain/module lists in CLAUDE.md to match actual directory structure
- Fix stale file paths in CLAUDE.md
- Archive completed plans to `.claude/plans/archive/`

### 3.2 Ask First (subjective or significant)

Presented for approval:
- Removing stale memory entries
- Moving content between parent/project CLAUDE.md
- Adding new rules or sections to CLAUDE.md
- Removing outdated rules from CLAUDE.md

## Presenting Findings

For each issue found, present:
- **What's wrong**: The specific inconsistency
- **Where**: Which file(s) are affected
- **Proposed fix**: The concrete change
- **Impact**: How this affects Claude's behavior

Categorize as:
- **Critical** — causes errors, broken paths, missing principles
- **Incorrect** — factually wrong, will cause confusion
- **Stale** — outdated references
- **Duplication** — rules repeated across levels
- **Cleanup** — plans/prompts/memory that can be archived
- **Improvement** — opportunities to enhance CLAUDE.md effectiveness

Wait for user approval before making changes (except auto-fix tier).
