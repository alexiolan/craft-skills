# Codex Executor Guide

Reference for how `develop` dispatches tasks to Codex when the profile includes codex. Used only by `develop`; other skills can ignore this file.

## When Codex runs

Profile-gated to `claude+codex` and `claude+codex+llm`:

```bash
case "$CRAFT_PROFILE" in
  *codex*) CODEX_ENABLED=1 ;;
  *)       CODEX_ENABLED=0 ;;
esac
```

If `CODEX_ENABLED=1`, Codex handles:
- Data layer tasks (types, services, queries, schemas, enums, mappers)
- Bulk mechanical fixes (lint/tsc repair sweeps)

All other task types stay on Claude regardless.

## Pre-flight check

Before dispatching any Codex task, run:

```bash
codex --version >/dev/null 2>&1 || {
  echo "ERROR: codex CLI not found."
  echo "Install: npm i -g @openai/codex"
  exit 1
}
```

No silent fallback to Claude. User explicitly chose a codex profile.

## Two-tier model routing

When Codex is routed a task, pick the model based on the target filename pattern:

| Target path glob | Model |
|---|---|
| Types, enums, schemas, mappers (simple data definitions) | `codex-mini` |
| Services, query hooks (API integration logic) | `gpt-5-codex` |
| Bulk lint/type-check fix sweeps | `codex-mini` |

Map these categories to your project's file structure. Example: `*/models/*.ts` -> types, `*/services/*Service.ts` -> services.

## Invocation shape

See `scripts/codex-dispatch.sh` for the canonical invocation. The invocation is:

```bash
codex exec \
  --full-auto \
  --sandbox workspace-write \
  -C "$PROJECT_ROOT" \
  --ephemeral \
  --output-schema "$CRAFT_SCRIPTS/codex-status-schema.json" \
  --output-last-message "$PROJECT_ROOT/.codex-output-$TASK_ID.json" \
  -m "$CODEX_MODEL" \
  - < "$PROJECT_ROOT/.codex-prompt-$TASK_ID.txt"
```

## Prompt template

See `skills/develop/codex-prompt.md` for the prompt template that `develop` fills in per task.

## Status protocol

Codex emits JSON conforming to `scripts/codex-status-schema.json` as its final message. `develop` reads `--output-last-message`, parses the JSON, and routes by status:

- `DONE` → verify shared-state updated, proceed
- `DONE_WITH_CONCERNS` → log concerns, decide if a fix agent is needed
- `NEEDS_CONTEXT` → provide missing context, re-dispatch
- `BLOCKED` → investigate, fix root cause, re-dispatch
- Invalid JSON → dispatch Claude sonnet reconcile agent
- Non-zero exit → dispatch Claude sonnet fallback agent for this task
