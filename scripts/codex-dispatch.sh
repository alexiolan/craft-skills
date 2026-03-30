#!/usr/bin/env bash
set -euo pipefail

# codex-dispatch.sh
# Dispatches a single task to Codex via codex exec.
#
# Usage:
#   codex-dispatch.sh <project-root> <task-id> <model> <prompt-file>
#
# Arguments:
#   project-root  — absolute path to the project root
#   task-id       — unique task identifier (used for output filenames)
#   model         — codex model name (e.g. codex-mini, gpt-5-codex)
#   prompt-file   — absolute path to a file containing the filled-in prompt
#
# Output files written to <project-root>:
#   .codex-output-<task-id>.json — Codex's final structured JSON message
#
# Exit codes:
#   0 — Codex exited successfully (check JSON status for task outcome)
#   2 — invocation error (bad args, missing codex CLI)
#   other — Codex exited non-zero (fallback needed)

PROJECT_ROOT="${1:-}"
TASK_ID="${2:-}"
CODEX_MODEL="${3:-gpt-5-codex}"
PROMPT_FILE="${4:-}"

if [[ -z "$PROJECT_ROOT" || -z "$TASK_ID" || -z "$PROMPT_FILE" ]]; then
  echo "ERROR: usage: codex-dispatch.sh <project-root> <task-id> <model> <prompt-file>" >&2
  exit 2
fi

if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "ERROR: project root does not exist: $PROJECT_ROOT" >&2
  exit 2
fi

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "ERROR: prompt file does not exist: $PROMPT_FILE" >&2
  exit 2
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "ERROR: codex CLI not found in PATH." >&2
  echo "Install: npm i -g @openai/codex" >&2
  exit 2
fi

# Locate the craft-skills scripts directory (this script's directory)
CRAFT_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$CRAFT_SCRIPTS/codex-status-schema.json"

if [[ ! -f "$SCHEMA_FILE" ]]; then
  echo "ERROR: schema file missing: $SCHEMA_FILE" >&2
  exit 2
fi

OUTPUT_FILE="$PROJECT_ROOT/.codex-output-$TASK_ID.json"

# Run Codex. Pipe prompt via stdin.
# Use set +e around codex so we can capture exit code without triggering errexit.
set +e
codex exec \
  --full-auto \
  --sandbox workspace-write \
  -C "$PROJECT_ROOT" \
  --ephemeral \
  --output-schema "$SCHEMA_FILE" \
  --output-last-message "$OUTPUT_FILE" \
  -m "$CODEX_MODEL" \
  - < "$PROMPT_FILE"
CODEX_EXIT=$?
set -e

if [[ $CODEX_EXIT -ne 0 ]]; then
  echo "WARN: codex exec exited with code $CODEX_EXIT for task $TASK_ID" >&2
  exit $CODEX_EXIT
fi

if [[ ! -f "$OUTPUT_FILE" ]]; then
  echo "WARN: codex exec produced no output file for task $TASK_ID" >&2
  exit 1
fi

echo "Codex task $TASK_ID complete. Output: $OUTPUT_FILE"
exit 0
