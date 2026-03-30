# Migrate Backend Project to craft-skills

You are migrating a backend project to use the `craft-skills` plugin and (optionally) a shared parent CLAUDE.md.

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

1. **Project identity**: What does this service do? What language/framework? (e.g., Python/FastAPI, Go/Gin, Node/Express, Java/Spring)
2. **Module structure**: How is the code organized? (packages, modules, layers)
3. **API surface**: Read route definitions, endpoints, or gRPC service definitions
4. **Database**: What ORM/database layer? (SQLAlchemy, Prisma, GORM, etc.)
5. **Authentication**: How does auth work? (JWT, OAuth, API keys, etc.)
6. **Shared utilities**: Where do shared types, helpers, and middleware live?
7. **Dev commands**: Read Makefile, package.json scripts, or equivalent
8. **Environment vars**: Read `.env.example` or config files (don't include secret values)
9. **Testing**: What test framework? Where do tests live?
10. **Deployment**: Docker, serverless, K8s? Any CI/CD config?
11. **Known tech debt**: Any known architectural issues?
12. **Logging**: Structured logging? What library?

## Step 3: Read the Parent CLAUDE.md (if exists)

If a parent workspace `CLAUDE.md` exists (at `../.claude/CLAUDE.md` relative to the project root), read it to understand what is already covered at the shared level. Your project CLAUDE.md must NOT duplicate any content from the parent. Only include project-specific information.

If no parent CLAUDE.md exists, your project CLAUDE.md must be self-contained.

## Step 4: Create Project-Specific CLAUDE.md

Create `.claude/CLAUDE.md` following this template (adapt sections based on what applies to this project):

```markdown
# CLAUDE.md — [Project Name]

Project-specific configuration for [brief description].

## Project Overview

[What this service does, 2-3 sentences]

## Tech Stack

- **Language**: [e.g., Python 3.12]
- **Framework**: [e.g., FastAPI 0.115]
- **Database**: [e.g., PostgreSQL via SQLAlchemy]
- **Testing**: [e.g., pytest with pytest-asyncio]

## Development Commands

```bash
[dev, build, test, lint, format commands]
```

## Environment Configuration

[Required env vars from .env.example]

## Module Structure

[How the project is organized — packages, layers, bounded contexts]

## API Surface

[Key endpoint groups or service definitions]

## Database Layer

[ORM setup, migration commands, model locations]

## Authentication

[How auth works in this service]

## Testing Strategy

[Test locations, fixtures, how to run specific test suites]

## Known Technical Debt

[Any known issues or architectural concerns]
```

**Important rules:**
- Only include sections that are relevant to this project
- Don't duplicate parent CLAUDE.md content (if a parent exists)
- Be specific — use actual file paths, actual module names
- Keep it concise

## Step 5: Clean Up Old Configuration

Remove any old configuration that is replaced by craft-skills:

```bash
# Remove old agents (replaced by skill-embedded prompts)
rm -rf .claude/agents/

# Remove old commands (replaced by skills)
rm -rf .claude/commands/
```

If there are old commands/agents with project-specific customizations NOT covered by craft-skills, note them for the user before deleting.

## Step 6: Update settings.json

Read `.claude/settings.json` and ensure craft-skills is referenced. Remove superpowers if present:

Remove `superpowers@claude-plugins-official` from `enabledPlugins` if present. Do NOT add craft-skills to settings.json manually — it is installed as a global plugin via marketplace and is already available.

The plugin is installed via:
```
/plugin marketplace add alexiolan/craft-skills
/plugin install craft-skills@craft-skills
```

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
3. If parent CLAUDE.md exists, verify it is accessible: `cat ../.claude/CLAUDE.md | head -3`
4. List project modules and confirm they match what's in the new CLAUDE.md
5. Run the project's lint/type-check/test commands to verify nothing is broken

## Step 9: Report

Present a summary:
- What was found (old config state)
- What was created (new CLAUDE.md)
- What was removed (old agents, commands, symlinks)
- What needs manual action (plugin installation, any flagged concerns)
- Recommend running `craft-skills:reflect project` after plugin installation to validate
