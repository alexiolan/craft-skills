---
name: llm-review
description: "Dispatch as a haiku agent to run local LLM tasks. Handles the full lifecycle: availability check, model loading, script execution, result collection, and model unloading. Other skills should dispatch this as an agent rather than running LLM bash commands directly."
---

# LLM Review

Full lifecycle wrapper for local LLM operations. **Other skills dispatch this as a haiku agent** — they never run LLM bash commands directly.

## How Other Skills Dispatch This

**Agents CANNOT invoke skills via the Skill tool.** Calling skills must provide the agent with complete operational instructions — not a skill name.

The correct dispatch pattern:
1. Read `dispatch-prompt.md` from this skill's directory (`<plugin-dir>/skills/llm-review/dispatch-prompt.md`)
2. Prepend task details: `CRAFT_SCRIPTS`, `Task`, `Keep loaded`
3. Dispatch as a **haiku** agent with the combined text as the prompt

The dispatch prompt contains the actual bash commands (`curl`, `llm-agent.sh`, `llm-review.sh`) that the agent runs directly via the Bash tool.

**NEVER** dispatch an agent with "Invoke craft-skills:llm-review" — the agent will silently ignore it and just read files with Claude, completely bypassing the local LLM.

**Task types:**
- `explore "<task>" <working-directory>` — Autonomous investigation (LLM reads files itself, saves the most tokens)
- `review <file-path> "<focus>"` — Single file review with thinking mode
- `analyze "<task>" <file1> <file2> ...` — Multi-file analysis

## Input

The user input is: `$ARGUMENTS`

- **Task type + arguments**: As described above
- **File path(s) + focus**: `/llm-review src/domain/auth/feature/LoginPage.tsx "security"`
- **Empty**: Ask the caller what to review

## Process

### Step 1: Locate Scripts

The scripts directory is provided at session start (bootstrap context) as `craft-skills scripts directory: <path>`. Use that path if available. Otherwise fall back to:

```bash
CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "llm-agent.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1)
```

If neither is available, return: "LLM scripts not found — craft-skills plugin may not be installed."

### Step 2: Check Availability

```bash
curl -s --max-time 2 ${LLM_URL:-http://127.0.0.1:1234} > /dev/null 2>&1 && echo "LLM_AVAILABLE" || echo "LLM_UNAVAILABLE"
```

If `LLM_UNAVAILABLE`, return: "LLM_UNAVAILABLE: LM Studio server not running."

### Step 3: Run the Task

> **Note:** Scripts auto-detect and fix context length (reload with 64K if loaded with less). No manual check needed.

Choose the script based on task type:

**review** — file content passed to LLM with thinking mode:
```bash
bash "$CRAFT_SCRIPTS/llm-review.sh" <file-path> "<focus>"
```

**analyze** — multiple files analyzed together:
```bash
bash "$CRAFT_SCRIPTS/llm-analyze.sh" "<task>" <file1> <file2> ...
```

**explore** — autonomous agent with file access tools (saves the most tokens):
```bash
bash "$CRAFT_SCRIPTS/llm-agent.sh" "<task description>" <working-directory>
```

If the script returns `LLM_ERROR` or exits non-zero, report the error — do not retry.
If the script returns `LLM_THINKING_OVERFLOW`, report: "Model used all tokens on reasoning. File may be too large for review mode — try explore mode instead."

### Step 4: Triage Findings

Before returning findings, filter out known false positives:
- The local model doesn't understand Claude Code plugins, skills, or agent dispatch
- Findings about "missing files" may be false if files exist in the plugin directory
- Focus on: structural issues, logic bugs, type mismatches, DDD violations, consistency

### Step 5: Unload Model

```bash
bash "$CRAFT_SCRIPTS/llm-unload.sh"
```

**Skip unloading if** the caller passes `Keep loaded: true` — this means another LLM step is expected soon.

### Step 6: Return

Return the triaged findings to the caller. Be concise — the caller will triage further against their conversation context.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `LLM_URL` | `http://127.0.0.1:1234` | LM Studio server URL |
| `LLM_MODEL` | `qwen/qwen3.5-35b-a3b` | Model identifier |

## Notes

- Thinking mode is enabled by default — fewer false positives
- Context window is set to 64K tokens automatically on load (scripts handle this)
- Typical time: 30-90 seconds for review, 1-3 minutes for explore
- Model uses ~22GB RAM when loaded — always unload when done unless told otherwise
