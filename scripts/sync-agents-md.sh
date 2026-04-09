#!/usr/bin/env bash
set -euo pipefail

# sync-agents-md.sh
# Generates AGENTS.md from CLAUDE.md so Codex has the same project context as Claude.
#
# Usage:
#   sync-agents-md.sh <project-root>
#
# Exits 0 on success, non-zero on failure. Idempotent.

PROJECT_ROOT="${1:-}"
if [[ -z "$PROJECT_ROOT" ]]; then
  echo "ERROR: project root required as first argument" >&2
  echo "Usage: sync-agents-md.sh <project-root>" >&2
  exit 2
fi

if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "ERROR: project root does not exist: $PROJECT_ROOT" >&2
  exit 2
fi

# Locate project CLAUDE.md — prefer .claude/CLAUDE.md, fall back to root
if [[ -f "$PROJECT_ROOT/.claude/CLAUDE.md" ]]; then
  CLAUDE_MD="$PROJECT_ROOT/.claude/CLAUDE.md"
elif [[ -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
  CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
else
  echo "WARN: no CLAUDE.md found at $PROJECT_ROOT/.claude/CLAUDE.md or $PROJECT_ROOT/CLAUDE.md — AGENTS.md not generated" >&2
  exit 1
fi

# Locate parent CLAUDE.md (one level up) — prefer .claude/CLAUDE.md
PARENT_CLAUDE_MD=""
if [[ -f "$PROJECT_ROOT/../.claude/CLAUDE.md" ]]; then
  PARENT_CLAUDE_MD="$PROJECT_ROOT/../.claude/CLAUDE.md"
elif [[ -f "$PROJECT_ROOT/../CLAUDE.md" ]]; then
  PARENT_CLAUDE_MD="$PROJECT_ROOT/../CLAUDE.md"
fi

# AGENTS.md is always written at project root (where Codex looks for it)
AGENTS_MD="$PROJECT_ROOT/AGENTS.md"

{
  cat <<'PREAMBLE'
# AGENTS.md

> This file is generated from CLAUDE.md by `scripts/sync-agents-md.sh`.
> Do NOT edit directly. Edit CLAUDE.md and re-run the sync script.

## Codex-specific constraints

These rules apply to all Codex executions in this project:

- Do NOT reformat existing code. Only change lines directly related to the task.
- Respect existing formatting and patterns, even if they differ from your defaults.
- Use named exports, not default exports.
- Follow the DDD structure strictly. Never import across business domain boundaries.
- When creating new files, match the style of existing files in the same directory.
- Never add files outside the scope of your specific task.
- Append your outputs (created files, exports, dependencies) to `.shared-state.md` before exiting.

---

PREAMBLE

  if [[ -n "$PARENT_CLAUDE_MD" ]]; then
    echo "## Parent CLAUDE.md"
    echo ""
    cat "$PARENT_CLAUDE_MD"
    echo ""
    echo "---"
    echo ""
  fi

  echo "## Project CLAUDE.md"
  echo ""
  cat "$CLAUDE_MD"
} > "$AGENTS_MD"

echo "AGENTS.md written to $AGENTS_MD"
