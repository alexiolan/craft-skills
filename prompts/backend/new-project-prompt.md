# Initialize New Backend Project with craft-skills

You are setting up Claude Code configuration for a new backend project. The project optionally uses a shared parent CLAUDE.md and the `craft-skills` plugin.

## Step 1: Understand the Project

Ask the user (one question at a time):

1. **What is this service?** Name, purpose, brief description.
2. **Tech stack**: Language? Framework? (e.g., Python/FastAPI, Go/Gin, Node/Express, Java/Spring)
3. **Database**: What database and ORM? (PostgreSQL/SQLAlchemy, MongoDB/Mongoose, etc.)
4. **Authentication**: What auth approach? (JWT, OAuth2, API keys, none, other)
5. **Initial modules**: What business modules will this service have? (e.g., users, orders, payments)

If the user provides a requirements document or description upfront, extract answers from it and only ask about gaps.

## Step 2: Read Parent CLAUDE.md (if exists)

If a parent workspace `CLAUDE.md` exists (at `../.claude/CLAUDE.md` relative to the project root), read it to understand what is already covered. Your project CLAUDE.md must NOT duplicate any of this content.

## Step 3: Scaffold .claude Directory

```bash
mkdir -p .claude/plans/specs
mkdir -p .claude/plans/archive
mkdir -p .claude/prompts
```

## Step 4: Create Project CLAUDE.md

Create `.claude/CLAUDE.md` with project-specific content only:

```markdown
# CLAUDE.md — [Project Name]

Project-specific configuration for [description].

## Project Overview

[2-3 sentences about what this service does]

## Tech Stack

- **Language**: [from Step 1]
- **Framework**: [from Step 1]
- **Database**: [from Step 1]
- **Testing**: [appropriate test framework for the stack]

## Development Commands

```bash
# Start development server
# Run tests
# Run linter
# Run type checker
# Build for production
```

## Environment Configuration

Required environment variables in `.env`:

[List based on what the project needs — DB connection, API keys, auth config, etc.]

## Module Structure

[Describe how modules are organized based on the chosen architecture]

## Authentication

[Describe based on Step 1 answer, or mark as TBD if not decided yet]

## Database Layer

[ORM setup, model locations, migration strategy]
```

**Rules:**
- Keep it minimal for new projects — it will grow as modules are added
- Don't include inventories of things that don't exist yet
- These sections get added naturally as the project evolves and `reflect` runs

## Step 5: Create settings.json

Create `.claude/settings.json` with any project-specific plugins needed:

```json
{
  "enabledPlugins": {
    "typescript-lsp@claude-plugins-official": true
  }
}
```

Do NOT add craft-skills here — it is installed globally via marketplace and is already available.

Adjust plugins based on what the project needs.

If craft-skills is not yet installed globally, the user should run:
```
/plugin marketplace add alexiolan/craft-skills
/plugin install craft-skills@craft-skills
```

## Step 6: Create .env.example

If the user provided environment details, create a `.env.example` with placeholder values:

```bash
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/dbname

# Auth
JWT_SECRET=your-secret-key
JWT_EXPIRY=3600

# API
PORT=8000
LOG_LEVEL=info
```

## Step 7: Scaffold Initial Module Structure

If the user specified initial modules, create the base directory structure appropriate for the chosen framework and architecture. Only scaffold directories — do NOT create placeholder files.

## Step 8: Report

Present a summary:
- Project CLAUDE.md created with initial configuration
- settings.json configured with project-specific plugins
- Directory structure scaffolded
- Remind user to:
  1. Verify craft-skills is installed globally (`/plugin list` should show craft-skills)
  2. Start building features using `craft-skills:craft` or `craft-skills:implement`
  3. Run `craft-skills:reflect project` after the first feature is complete to update CLAUDE.md
