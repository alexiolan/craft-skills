---
name: bootstrap
description: "Loaded at session start. Establishes awareness of craft-skills so the assistant invokes relevant skills before acting. Not invoked directly."
---

# craft-skills Bootstrap

You have access to the **craft-skills** plugin — a set of DDD-first frontend development skills for Next.js projects.

## Extremely Important

If there is even a 1% chance that a craft-skill applies to what you are about to do, you MUST invoke it via the Skill tool BEFORE taking action. Skills override your default behavior with battle-tested workflows.

## Instruction Priority

1. **User instructions** — always highest priority
2. **craft-skills** — override default behavior when applicable
3. **Default system prompt** — fallback when no skill applies

## Available Skills

### Process Skills (invoke first when applicable)

| Skill | Trigger Conditions |
|---|---|
| `craft-skills:debug` | Bug report, error investigation, failing tests, unexpected behavior. Invoke BEFORE attempting any fix. |
| `craft-skills:reflect` | User asks to audit, improve, or maintain Claude configs/skills. Also: periodic maintenance. |
| `craft-skills:simplify` | After implementation is done, review changed code for reuse/quality. |

### Implementation Skills

| Skill | Trigger Conditions |
|---|---|
| `craft-skills:craft` | New feature with unclear/complex requirements. User says "craft", "design", "brainstorm", or describes a feature that needs exploration. |
| `craft-skills:implement` | New feature with clear requirements. User says "implement", provides a prompt file number, or gives clear feature description. |
| `craft-skills:finalize` | Plan already exists (from brainstorming or architect). User says "finalize", "execute the plan", or references an existing plan file. |
| `craft-skills:architect` | User wants only planning, no implementation. User says "plan", "architect", or "how should we approach". |
| `craft-skills:develop` | Approved plan exists, ready to execute. User says "develop", "build it", or references a plan to execute. |
| `craft-skills:browser-test` | Feature is built, needs browser testing. User says "test in browser", "check the UI", or testing is the next pipeline step. |

### Priority Order

When multiple skills could apply:
1. **Process skills first** — debug before fixing, reflect before changing configs
2. **Pipeline skills** — craft/implement for full workflows, architect/develop/browser-test for individual steps
3. If uncertain between craft and implement → ask the user about requirement clarity

## DDD-Aware Triggers

Before any implementation work, check:
- **New domain feature?** → architect or craft (not direct implementation)
- **Form changes?** → Check existing fields in `src/domain/forms/fields/` first
- **Cross-domain need?** → Check `src/domain/shared/` first, consider moving to shared
- **Bug fix?** → debug skill first, then fix

## Rationalization Prevention

Do NOT skip skills because:

| Excuse | Reality |
|---|---|
| "This is too simple" | Simple tasks have the most unexamined assumptions |
| "I already know the answer" | Skills enforce process, not just answers |
| "It would be faster without the skill" | Skipping skills causes rework that wastes more time |
| "The user didn't ask for it" | Skills are invoked automatically when relevant |
| "I just need to make a quick fix" | debug skill exists precisely for this — investigate first |
| "I'll just explore first" | Exploring IS the first step of the relevant skill |

## What Skills Do NOT Cover

- Simple questions about the codebase (just answer them)
- Reading/explaining existing code (just do it)
- Git operations (just execute them)
- Configuration changes unrelated to Claude/skills (just make them)

When no skill applies, proceed normally following the project's CLAUDE.md conventions.
