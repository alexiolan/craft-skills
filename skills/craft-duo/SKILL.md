---
name: craft-duo
description: "Full design-first pipeline with Codex as a co-executor for data-layer tasks. Claude handles architecture and UI; Codex handles types, services, queries, schemas, enums, mappers, and bulk fixes. Use when you want cost relief via Codex without losing Claude's reasoning on UI and integration."
---

# Craft (duo variant: Claude + Codex)

Full design-first pipeline. Claude does brainstorming, architect planning, UI implementation, and integration wiring. Codex handles data-layer tasks via `codex exec`.

**Profile:** `claude+codex`

**Pipeline:** Brainstorm → Plan → Develop (hybrid executors) → Browser Test → Report (same phases as `/craft`)

## Requirements

- Codex CLI installed: `npm i -g @openai/codex`
- Codex authenticated: `codex login` (ChatGPT auth) or set `OPENAI_API_KEY`
- `AGENTS.md` present at project root (auto-generated from CLAUDE.md by `develop` pre-flight if missing or stale)

Does NOT require LM Studio.

## How this wrapper works

This wrapper writes the profile marker, then delegates to the canonical craft pipeline. The `develop` skill reads `.craft-profile` and routes data-layer tasks to Codex instead of Claude sonnet agents.

## Step 1: Write profile marker

```bash
echo -n "claude+codex" > .craft-profile
```

## Step 2: Follow the craft pipeline

Read `skills/craft/SKILL.md` from this plugin and follow every phase exactly as written. Profile gating in the craft and develop skills routes the relevant tasks to Codex.

The user input is: `$ARGUMENTS`

Pass the input through as if the user had invoked `/craft`.

## Expected behavior differences from `/craft`

- `develop` Step 0 runs a Codex CLI pre-flight check — fails loud if Codex is missing
- `develop` Step 2 routes data-layer tasks (`types`, `services`, `queries`, `schemas`, `enums`, `mappers`) to Codex
- `develop` Step 2 also routes bulk lint/tsc fix sweeps to Codex
- UI and integration tasks stay on Claude sonnet/opus
- LLM steps are skipped (no LM Studio dependency)

## Expected cost relief

Typical feature runs delegate ~30-40% of lines-of-code work to Codex, translating to roughly 15-20% overall cost relief per run. Varies significantly by feature shape: heavy data-layer features see more relief, UI-heavy features see less.
