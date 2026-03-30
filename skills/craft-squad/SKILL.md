---
name: craft-squad
description: "Full design-first pipeline with all three AI agents: Claude (architect + UI + integration), Codex (data-layer + bulk fixes), and local LLM (LM Studio, for exploration + review). Power-user mode. Optionally runs Codex adversarial review if codex-plugin-cc is installed."
---

# Craft (squad variant: Claude + Codex + local LLM)

Full design-first pipeline with every AI component active. Combines `/craft-duo` (Codex for data layer) with `/craft-local` (LM Studio for review/exploration). Optionally enables a skeptical adversarial review from Codex via `codex-plugin-cc` if installed.

**Profile:** `claude+codex+llm`

**Pipeline:** Brainstorm → Plan → Develop (hybrid executors + LLM reviews + optional adversarial review) → Browser Test → Report

## Requirements

- Codex CLI installed: `npm i -g @openai/codex`
- Codex authenticated: `codex login` or `OPENAI_API_KEY`
- LM Studio running at `${LLM_URL:-http://127.0.0.1:1234}`
- `AGENTS.md` at project root (auto-generated)
- **Optional:** `codex-plugin-cc` installed in Claude Code — enables adversarial review bonus

## How this wrapper works

Writes the profile marker, then delegates to the canonical craft pipeline.

## Step 1: Write profile marker

```bash
echo -n "claude+codex+llm" > .craft-profile
```

## Step 2: Follow the craft pipeline

Read `skills/craft/SKILL.md` and follow every phase. All profile gates are satisfied: LLM steps run, Codex routing activates, and the develop skill checks for `codex-plugin-cc` to optionally run an adversarial review.

The user input is: `$ARGUMENTS`

## Expected behavior

- All LLM steps run (LM Studio required)
- All Codex routing runs (Codex CLI required)
- If `codex-plugin-cc` is installed, `develop` Step 3.5 invokes `/codex:adversarial-review` on the diff as a skeptical second-opinion review
- If `codex-plugin-cc` is NOT installed, the adversarial review step is silently skipped — no failure

## When to use

Use `/craft-squad` when:
- Stakes are high and you want every layer of review
- The feature is complex enough that a skeptical second opinion matters
- You have both LM Studio and Codex CLI available

For most day-to-day work, `/craft-duo` (no LLM) or `/craft` (no external deps) are usually enough.
