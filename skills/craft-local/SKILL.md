---
name: craft-local
description: "Same as /craft but with local LLM review steps enabled. Use when you have LM Studio running and want LLM-assisted spec/plan/post-develop reviews. Preserves pre-1.1 craft behavior."
---

# Craft (local LLM variant)

Full design-first pipeline with LM Studio as a supplementary review agent. Identical to `/craft` except that LLM pre-exploration, spec review, plan review, and post-develop review steps all run.

**Profile:** `claude+llm`

**Pipeline:** Brainstorm → Plan → Develop → Browser Test → Report (same as `/craft`)

## How this wrapper works

This wrapper is ~1 step of delegation. The actual pipeline logic lives in `skills/craft/SKILL.md`. This file writes the profile marker, then instructs you to follow the craft pipeline.

## Step 1: Write profile marker

```bash
echo -n "claude+llm" > .craft-profile
```

## Step 2: Follow the craft pipeline

Read `skills/craft/SKILL.md` from this plugin and follow every phase exactly as written. The profile gating in that file ensures LLM steps run when profile is `claude+llm`.

The user input is: `$ARGUMENTS`

Pass the input through to the craft pipeline as if the user had invoked `/craft` directly.

## Notes

- Requires LM Studio running at `${LLM_URL:-http://127.0.0.1:1234}`
- Does NOT require Codex CLI
- All LLM steps will run; expect ~30% longer runs than `/craft` in exchange for deeper review
