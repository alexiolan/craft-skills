# Craft Core Pipeline (reference)

This directory contains the shared pipeline logic for the `craft` family of skills (`/craft`, `/craft-duo`, `/craft-local`, `/craft-squad`). Wrapper skills write a profile value to `.craft-profile` and then follow the pipeline defined here.

## Files in this directory

- `profiles.md` — profile definitions, `.craft-profile` protocol, gating helpers
- `llm-gating.md` — where and how local LLM steps are skipped per profile
- `codex-executor.md` — Codex dispatch reference used by `develop`
- `core.md` — this file (pipeline index)

## Pipeline phases

The craft pipeline has five phases. All wrappers run the same phases; profile gating affects which substeps run inside each phase.

1. **Brainstorm** — collaborative design exploration with the user, spec writing, spec review
2. **Plan** — implementation plan creation, plan review
3. **Develop** — dispatch implementation tasks (profile-aware executor routing)
4. **Test** — browser testing
5. **Report** — summary

## Profile-gated substeps (summary)

| Phase / Step | `claude` | `claude+codex` | `claude+llm` | `claude+codex+llm` |
|---|---|---|---|---|
| 1.1 LLM pre-exploration | skip | skip | run | run |
| 1.10 LLM spec review | skip | skip | run | run |
| 2.4 LLM plan review | skip | skip | run | run |
| 3 Data layer dispatch | Claude sonnet | **Codex** | Claude sonnet | **Codex** |
| 3 UI dispatch | Claude sonnet | Claude sonnet | Claude sonnet | Claude sonnet |
| 3 Integration dispatch | Claude opus | Claude opus | Claude opus | Claude opus |
| 3.5 LLM post-develop review | skip | skip | run | run |
| 3.5 Codex adversarial review | skip | run (if plugin installed) | skip | run (if plugin installed) |

## Graph tools (always on)

Graph tools (`code-review-graph` MCP) run in every variant unconditionally. They are deterministic infrastructure, not AI.

## Wrapper responsibilities

Each wrapper SKILL.md is ~30 lines and does exactly two things:

1. Write the profile value to `.craft-profile`
2. Instruct Claude to follow the canonical pipeline (currently in `craft/SKILL.md`; in future refactors, may move here)

## Invariant

Never delete `.craft-profile` before `develop` finishes. It is cleaned up as part of `develop` Step 5 cleanup, alongside `.shared-state.md`.
