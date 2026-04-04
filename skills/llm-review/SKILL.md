---
name: llm-review
description: "Use when you need a supplementary code review from a local LLM. Auto-loads the model into RAM, runs the review with thinking mode, and unloads when done. Free, runs locally, provides a second opinion from a different model architecture. Invoke for spec reviews, plan reviews, or post-implementation code reviews."
---

# LLM Review

Run a local LLM review on one or more files. The model auto-loads into RAM, performs the review with thinking/reasoning mode for higher accuracy, and auto-unloads when done to free memory.

## Input

The user input is: `$ARGUMENTS`

- **File path(s)** and optional focus area: `/llm-review src/domain/auth/feature/LoginPage.tsx "security, error handling"`
- **Empty**: Ask the user what file(s) to review

## Prerequisites

- [LM Studio](https://lmstudio.ai) installed with local server running
- Model `qwen/qwen3.5-35b-a3b` downloaded in LM Studio
- Scripts are in the craft-skills plugin directory — the full path is provided at session start (bootstrap context). If not in context, locate it: `find ~/.claude/plugins -name "llm-agent.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1`

Locate scripts: `CRAFT_SCRIPTS=$(find ~/.claude/plugins -name "llm-agent.sh" -path "*/craft-skills/*" -exec dirname {} \; 2>/dev/null | head -1)` — or use the path from bootstrap context if available. All script references below use `$CRAFT_SCRIPTS` as the path prefix.

## Process

### Step 1: Check Availability

Check LM Studio is running: `curl -s --max-time 2 ${LLM_URL:-http://127.0.0.1:1234} > /dev/null 2>&1 && echo "LLM_AVAILABLE" || echo "LLM_UNAVAILABLE"`

If `LLM_UNAVAILABLE`, inform the user:
> "Local LLM is not available. Make sure LM Studio is running with the local server started."

If `LLM_AVAILABLE`, proceed.

### Step 2: Run Review

Choose the right script for the task:

**Single file review** (file content passed to LLM):
```
bash $CRAFT_SCRIPTS/llm-review.sh <file-path> "<focus>"
```

**Multiple files analyzed together** (all content passed to LLM):
```
bash $CRAFT_SCRIPTS/llm-analyze.sh "<task>" <file1> <file2> ...
```

**Autonomous investigation** (LLM reads files itself — Claude saves the most tokens):
```
bash $CRAFT_SCRIPTS/llm-agent.sh "<task description>" <working-directory>
```
The agent has `read_file`, `list_dir`, and `search_code` tools. It autonomously explores the codebase and returns findings. Use this when the task requires investigating multiple files or when you don't know which files to look at.

Run in the background (use `run_in_background: true`) if invoked in parallel with other work.

### Step 3: Present Findings

Present the LLM's findings to the user or to the calling skill. Note that local LLM findings should be **triaged** — not all findings are valid:
- The local model doesn't understand Claude Code plugin namespaces, skill invocations, or agent dispatch patterns
- Findings about "missing files" may be false if the files exist in the plugin directory
- Focus on structural issues, logic bugs, and consistency findings

### Step 4: Unload Model

Run `bash $CRAFT_SCRIPTS/llm-unload.sh` to free RAM.

**Skip unloading if** another LLM step is expected soon (e.g., this was a spec review and plan review is coming next). In that case, leave the model loaded and unload after the last LLM step.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `LLM_URL` | `http://127.0.0.1:1234` | LM Studio server URL |
| `LLM_MODEL` | `qwen/qwen3.5-35b-a3b` | Model identifier |

## Notes

- Thinking mode is enabled by default — the model reasons internally before answering, producing fewer false positives
- Context window is set to 64K tokens automatically on load
- Typical review time: 30-90 seconds per file depending on size
- The model uses ~22GB RAM when loaded
