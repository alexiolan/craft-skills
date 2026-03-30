---
name: implement
description: "Use when implementing a feature with clear, well-understood requirements. Quick planning via architect agent, then parallel agent development, then browser testing. Faster than craft — use when requirements don't need deep exploration."
---

# Implement

Fast end-to-end implementation pipeline. Quick planning, then development, then testing.

**Pipeline:** Architect → Develop → Browser Test → Report

## Input

The user input is: `$ARGUMENTS`

### Input Type Detection

1. **Prompt File Number** (e.g., `01`, `07`):
   - Read from `.claude/prompts/{number}*.md`

2. **Direct Prompt Text**:
   - Use directly as feature requirements

3. **Empty Input**:
   - Ask the user to provide a prompt file number or direct requirements

## Phase 1: Architect

1. Invoke `craft-skills:architect` with the requirements
2. Relay any clarification questions to the user
3. Review the plan for alignment, reuse, and best practices
4. Wait for user approval (allow iterations if changes requested)

If the architect raises too many ambiguities, suggest switching to `craft-skills:craft` for deeper exploration.

## Phase 2: Develop

After plan approval, invoke `craft-skills:develop` with the approved plan.

## Phase 3: Browser Test

After a successful build, invoke `craft-skills:browser-test`.

## Phase 4: Report

Summarize:
- Plan decisions from Phase 1
- Files created/modified from Phase 2
- Test results from Phase 3
- Any open items

## When to Use implement vs craft

| | implement | craft |
|---|---|---|
| **Planning** | Quick architect agent | Deep brainstorming + spec review |
| **User involvement** | Medium — plan review | High — design questions, approach selection |
| **Best for** | Clear requirements, well-understood scope | Complex domains, unclear requirements |
