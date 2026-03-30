# Migrate Project to craft-skills

You are migrating this project to use the `craft-skills` plugin and the shared parent CLAUDE.md at `frontend/.claude/CLAUDE.md`.

## Step 1: Understand Current State

Read all existing Claude configuration:
- `.claude/CLAUDE.md` (if exists)
- All files in `.claude/agents/` (if exists)
- All files in `.claude/commands/` (if exists)
- `.claude/settings.json` (if exists)
- `.claude/settings.local.json` (if exists)

Check for symlinks:
```bash
file .claude/CLAUDE.md
file .claude/agents
file .claude/commands
```

## Step 2: Understand the Project

Analyze the codebase to gather project-specific information:

1. **Project identity**: What does this app do? What framework/version?
2. **Domain list**: `ls src/domain/` — list all business and shared domains
3. **Routing**: Read `src/app/` structure or routing config
4. **Authentication**: How does auth work? (iron-session, next-auth, custom?)
5. **HTTP clients**: Read `src/domain/network/` for API client setup
6. **Shared components**: `ls src/domain/shared/ui/` and `ls src/domain/shared/hooks/`
7. **Dev commands**: Read `package.json` scripts section
8. **Environment vars**: Read `.env.example` or `.env` (don't include secret values)
9. **Backend integration**: Is there a backend project referenced as additional directory?
10. **Domain-specific notes**: For established domains, note key services, models, queries
11. **Known tech debt**: Any DDD violations or known issues?
12. **Dev logger**: Does the app have a devLogger or structured console logging?

## Step 3: Read the Parent CLAUDE.md

Read `/Users/alex/Projects/frontend/.claude/CLAUDE.md` to understand what is already covered at the shared level. Your project CLAUDE.md must NOT duplicate any content from the parent. Only include project-specific information.

## Step 4: Create Project-Specific CLAUDE.md

Create `.claude/CLAUDE.md` following this template (adapt sections based on what applies to this project):

```markdown
# CLAUDE.md — [Project Name]

Project-specific configuration for [brief description]. Generic DDD/Next.js conventions are in the parent `frontend/.claude/CLAUDE.md`.

## Project Overview

[What this app does, 2-3 sentences]

## Development Commands

```bash
[npm/yarn scripts from package.json]
```

## Environment Configuration

[Required env vars from .env.example]

## Business Domains

**Shared/Utility Domains**: [list]

**Business Domains** (isolated): [list from src/domain/]

## HTTP Client Instances

[If different from the generic pattern in parent CLAUDE.md]

## Routing Structure

[App router structure]

## Authentication Flow

[If applicable — how auth works in this project]

## Shared Components Inventory

[List of actual shared UI components and hooks in this project]

## Domain-Specific Notes

[For each established domain: service, models, queries, features]

## Known Technical Debt

[Any known issues, DDD violations, etc.]

## Backend Integration

[If applicable — backend project reference]

## Dev Logger

[If applicable — console logging conventions]
```

**Important rules:**
- Only include sections that are relevant to this project
- Don't duplicate parent CLAUDE.md content (architecture patterns, form rules, working principles, etc.)
- Be specific — use actual file paths, actual domain names, actual component names
- Keep it concise — project CLAUDE.md should be shorter than the parent

## Step 5: Clean Up Old Configuration

Remove any old configuration that is replaced by craft-skills:

```bash
# Remove old agents (replaced by skill-embedded prompts)
rm -rf .claude/agents/

# Remove old commands (replaced by skills)
rm -rf .claude/commands/

# Remove symlinks if any exist (replaced by parent CLAUDE.md + plugin)
# Only remove if they are symlinks, not real files with unique content
```

If there are old commands/agents with project-specific customizations NOT covered by craft-skills, note them for the user before deleting.

## Step 6: Update settings.json

Read `.claude/settings.json` and ensure craft-skills is referenced. Remove superpowers if present:

```json
{
  "enabledPlugins": {
    "craft-skills@local": true
    // ... keep other plugins (playwright, code-review-graph, etc.)
    // Remove: "superpowers@claude-plugins-official": true
  }
}
```

Note: The user will need to install the plugin via CLI: `claude plugin install /Users/alex/Projects/frontend/craft-skills` or the appropriate command.

## Step 7: Create Required Directories

Ensure these directories exist:
```bash
mkdir -p .claude/plans/specs
mkdir -p .claude/plans/archive
mkdir -p .claude/prompts
```

## Step 8: Validate

Run a quick validation:

1. Verify `.claude/CLAUDE.md` exists and has project-specific content only
2. Verify no agents/ or commands/ directories remain
3. Verify parent CLAUDE.md is accessible: `cat /Users/alex/Projects/frontend/.claude/CLAUDE.md | head -3`
4. List all domains and confirm they match what's in the new CLAUDE.md:
   ```bash
   ls src/domain/
   ```
5. Check that shared components/hooks listed actually exist

## Step 9: Report

Present a summary:
- What was found (old config state)
- What was created (new CLAUDE.md)
- What was removed (old agents, commands, symlinks)
- What needs manual action (plugin installation, any flagged concerns)
- Recommend running `craft-skills:reflect project` after plugin installation to validate
