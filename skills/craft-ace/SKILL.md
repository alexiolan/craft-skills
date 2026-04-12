---
name: craft-ace
description: "Cost-optimized craft variant: Gemma 4 26B handles implementation and reviews locally, Opus orchestrates, Sonnet as fallback. Requires LM Studio running. Targets ~45-60% API cost reduction vs base /craft."
---

# Craft ACE (Autonomous Claude Engine)

Full design-first pipeline with Gemma as the primary implementer and reviewer. Opus orchestrates and handles integration. Sonnet serves as fallback for tasks Gemma can't handle.

**Profile:** `claude+ace`

**Pipeline:** Brainstorm -> Plan -> Develop -> Browser Test -> Report (same as `/craft`)

## How this wrapper works

This wrapper writes a profile marker, then delegates to the canonical craft pipeline. The `claude+ace` profile triggers:
- Gemma replaces Opus/Sonnet for spec and plan reviews (review loops, max 4 rounds)
- Gemma handles all implementation tasks (data layer + UI)
- Sonnet fallback for failed Gemma UI tasks
- Opus handles integration/wiring tasks only

## Step 1: Write profile marker

```bash
echo -n "claude+ace" > .craft-profile
```

## Step 2: Follow the craft pipeline

Read `skills/craft/SKILL.md` from this plugin and follow every phase exactly as written. The profile gating in that file ensures:
- Step 1.10 (spec review): Gemma review loop replaces opus agent review
- Step 2.4 (plan review): Gemma review loop replaces sonnet agent review
- Step 3 (develop): Tasks routed to `llm-implement.sh` instead of Claude agents

The user input is: `$ARGUMENTS`

Pass the input through to the craft pipeline as if the user had invoked `/craft` directly.

## Requirements

- LM Studio running at `${LLM_URL:-http://127.0.0.1:1234}`
- Gemma 4 26B A4B (8-bit) model loaded or available for auto-load
- Does NOT require Codex CLI
- Graph built on target project recommended (falls back to Glob)

## Cost Model

| Activity | Savings vs /craft |
|---|---|
| Reviews (spec, plan, post-develop) | 100% (all local) |
| Data layer implementation (~40-50% LoC) | 100% (all local) |
| UI implementation (~30-40% LoC) | ~30-50% (Gemma first, Sonnet fallback) |
| Integration (~10-20% LoC) | 0% (stays on Opus) |
| **Total estimated savings** | **~45-60%** |
