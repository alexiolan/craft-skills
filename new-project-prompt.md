# Initialize New Project with craft-skills

You are setting up Claude Code configuration for a brand new frontend project under `frontend/`. The project uses the shared parent CLAUDE.md at `frontend/.claude/CLAUDE.md` and the `craft-skills` plugin.

## Step 1: Understand the Project

Ask the user (one question at a time):

1. **What is this project?** Name, purpose, brief description.
2. **Tech stack confirmation**: Next.js version? Any deviations from the standard DDD setup?
3. **Backend**: Is there a backend API project? Where is it located?
4. **Authentication**: What auth approach? (PKCE + iron-session, next-auth, none, other)
5. **Initial domains**: What business domains will this project have? (e.g., products, orders, users)

If the user provides a requirements document or description upfront, extract answers from it and only ask about gaps.

## Step 2: Read Parent CLAUDE.md

Read `/Users/alex/Projects/frontend/.claude/CLAUDE.md` to understand what is already covered. Your project CLAUDE.md must NOT duplicate any of this content.

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

Project-specific configuration for [description]. Generic DDD/Next.js conventions are in the parent `frontend/.claude/CLAUDE.md`.

## Project Overview

[2-3 sentences about what this app does]

## Development Commands

```bash
npm run dev              # Start development server
npm run build           # Build production bundle
npm run lint            # Run ESLint
npm run format          # Format code with Prettier
```

## Environment Configuration

Required environment variables in `.env`:

[List based on what the project needs — API URLs, auth config, session keys, etc.]

## Business Domains

**Shared/Utility Domains**: `shared`, `network`, `forms`

**Business Domains** (isolated, cannot import from each other):
- [List initial domains from Step 1]

## HTTP Client Instances

[Describe API client setup — which APIs does this project talk to?]

## Routing Structure

```
app/
├── (auth)/              # Unauthenticated routes
├── (authenticated)/     # Protected routes
│   └── [describe initial route groups]
└── api/                 # API routes
```

## Authentication Flow

[Describe based on Step 1 answer, or mark as TBD if not decided yet]

## Backend Integration

[If applicable — path to backend project as additional working directory]
```

**Rules:**
- Keep it minimal for new projects — it will grow as domains are added
- Don't include shared components/hooks inventory yet (nothing exists)
- Don't include domain-specific notes yet (no domains built)
- These sections get added naturally as the project evolves and `reflect` runs

## Step 5: Create settings.json

Create `.claude/settings.json` with any project-specific plugins needed:

```json
{
  "enabledPlugins": {
    "playwright@claude-plugins-official": true,
    "typescript-lsp@claude-plugins-official": true
  }
}
```

Do NOT add craft-skills here — it is installed globally via marketplace and is already available.

Adjust plugins based on what the project needs. Common additions:
- `code-review-graph@code-review-graph` — for large codebases
- `ui-ux-pro-max@ui-ux-pro-max-skill` — for design-heavy projects

If craft-skills is not yet installed globally, the user should run:
```
/plugin marketplace add alexiolan/craft-skills
/plugin install craft-skills@craft-skills
```

## Step 6: Create .env.example

If the user provided environment details, create a `.env.example` with placeholder values:

```bash
# API
NEXT_PUBLIC_API_URL=http://localhost:5000

# Auth
NEXT_PUBLIC_IDENTITY_URL=https://identity.example.com
NEXT_PUBLIC_IDENTITY_CLIENT=your-client-id
NEXT_PUBLIC_APP_URL=http://localhost:3000
NEXT_PUBLIC_SESSION_PASSWORD=at-least-32-characters-long-secret-key
```

## Step 7: Scaffold Initial Domain Structure

If the user specified initial domains, create the base directory structure:

```bash
# For each business domain
mkdir -p src/domain/{domain-name}/data/{enums,infrastructure,models,schemas,queries}
mkdir -p src/domain/{domain-name}/{feature,ui,hooks,utils}

# Shared domains (always needed)
mkdir -p src/domain/shared/{data/models,data/queries,ui,hooks,utils}
mkdir -p src/domain/network/{data/infrastructure,hooks,utils}
mkdir -p src/domain/forms/{fields,hooks}
```

Only scaffold directories — do NOT create placeholder files. Files get created when actual features are implemented.

## Step 8: Report

Present a summary:
- Project CLAUDE.md created with initial configuration
- settings.json configured with project-specific plugins
- Directory structure scaffolded
- Remind user to:
  1. Verify craft-skills is installed globally (`/plugin list` should show craft-skills)
  2. Start building features using `craft-skills:craft` or `craft-skills:implement`
  3. Run `craft-skills:reflect project` after the first feature is complete to update CLAUDE.md with actual component/hook inventory
