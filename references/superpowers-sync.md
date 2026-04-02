# Superpowers Sync Status

## Last Sync
- **Date:** 2026-04-02
- **Version:** 5.0.7
- **Repository:** https://github.com/obra/superpowers

## Absorbed Methodology

| Superpowers Skill | Absorbed Into | Key Ideas Kept |
|---|---|---|
| brainstorming | craft | Business requirement exploration, one-question-at-a-time, 2-3 approaches, section-by-section approval, spec self-review |
| writing-plans | craft + architect | Bite-sized tasks (2-5 min), no placeholders, complete code in every step, file structure mapping |
| subagent-driven-development | develop | Fresh agent per task, two-stage review (spec compliance + code quality) |
| dispatching-parallel-agents | develop | Focused scope per agent, self-contained context, specific output expectations |
| verification-before-completion | all pipeline skills | Iron law: no completion claims without fresh verification evidence |
| systematic-debugging | debug | Four phases: root cause, pattern analysis, hypothesis, implementation |
| using-superpowers | bootstrap | Skill awareness, rationalization prevention, auto-trigger rules |

## Changelog

### 2026-03-30 — Initial absorption from v5.0.5
- Created craft-skills package absorbing methodology from superpowers 5.0.5
- Dropped: visual companion, git-worktrees, TDD, writing-skills, receiving/requesting code review, finishing-a-development-branch

### 2026-04-02 — Sync to v5.0.7
- **Adopted:** Plan header for agentic workers (architect-prompt.md), implementer status codes DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED (develop SKILL.md + implementer-prompt.md)
- **Already present:** HARD-GATE on brainstorming (craft), spec self-review (craft), user review gate (craft), instruction priority hierarchy (bootstrap), scope assessment/decomposition (craft)
- **Skipped:** Visual companion (we use browser-test post-implementation), model selection guidance (not relevant — single model), multi-platform support (Claude Code only), TDD/code-review/writing-skills/finishing-branch (intentionally dropped)
