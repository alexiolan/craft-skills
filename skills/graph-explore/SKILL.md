---
name: graph-explore
description: "Dispatch as a haiku agent to run code-review-graph queries. Handles graph freshness, embedding setup, semantic search, and targeted queries. Other skills should dispatch this as an agent rather than calling graph tools directly."
---

# Graph Explore

Haiku agent wrapper for code-review-graph operations. Absorbs all graph query tokens and returns only a structured summary. **Other skills dispatch this as a haiku agent** — they never call graph MCP tools directly.

## How Other Skills Use This

Skills dispatch a **haiku** agent with this skill loaded, passing a task description. The agent handles everything and returns only the findings:

```
Agent(model: "haiku", prompt: "Invoke craft-skills:graph-explore with task: [explore/impact/review] ...")
```

**Task types:**
- `explore "<feature keywords>" <repo-root>` — Full feature discovery: semantic search, file summaries, dependency mapping
- `impact "<file1> <file2> ..."` — Blast radius analysis for changed files
- `review` — Post-develop review context (auto-detects changed files from git)

## Input

The user input is: `$ARGUMENTS`

- **Task type + arguments**: As described above
- **Empty**: Ask the caller what to explore

## Process

### Step 1: Load Graph Tools

Load these tools via `ToolSearch` at the start:
- `mcp__plugin_code-review-graph_code-review-graph__build_or_update_graph_tool`
- `mcp__plugin_code-review-graph_code-review-graph__semantic_search_nodes_tool`
- `mcp__plugin_code-review-graph_code-review-graph__query_graph_tool`
- `mcp__plugin_code-review-graph_code-review-graph__embed_graph_tool`
- `mcp__plugin_code-review-graph_code-review-graph__get_impact_radius_tool`
- `mcp__plugin_code-review-graph_code-review-graph__get_review_context_tool`

If tools are not available (MCP server not connected), return: "GRAPH_UNAVAILABLE: code-review-graph MCP server not connected."

### Step 2: Ensure Graph is Fresh

Run `build_or_update_graph_tool` (incremental — fast if already up-to-date).

### Step 3: Ensure Embeddings Exist

Run a test search with `semantic_search_nodes_tool` using a common keyword (e.g., "service").

If `search_mode` in the response is `"keyword"` (not `"semantic"`), embeddings are missing. Run `embed_graph_tool` to compute them. This is a one-time operation (~30s for ~1000 nodes).

If `search_mode` is `"semantic"`, embeddings are ready.

### Step 4: Execute Task

#### Mode: `explore`

Goal: Map existing code related to a feature, so the caller can design without reading files.

1. **Semantic search** — Run `semantic_search_nodes_tool` with the feature keywords. Try 2-3 keyword variations if first returns few results (e.g., "referral invite" then "email send notification" then "discount credit").
2. **Map structure** — For each relevant domain directory found, run `query_graph_tool` with `file_summary` to list all files and their contents.
3. **Trace dependencies** — For the most relevant files, run `query_graph_tool` with `imports_of` and `importers_of` to understand how they connect.
4. **Consolidate** — Return a structured summary organized by domain.

**Output format:**
```
## Graph Exploration: [keywords]

### Relevant Code Found
- [file path] — [what it contains, key exports]
- ...

### Domain Structure
- domain/X/ — [summary of what's in this domain]
- ...

### Key Dependencies
- [file A] imports [file B] (for [purpose])
- ...

### Suggested Starting Points
- [file] — [why it's relevant to the feature]
```

**Safety rules:**
- Do NOT use `get_architecture_overview_tool`, `list_communities_tool`, or `detect_changes_tool` — they can return 90-300K+ chars and overflow context.
- Limit `file_summary` queries to specific domain directories, not the entire `src/`.
- Cap at 5-6 `query_graph_tool` calls to avoid excessive output.

#### Mode: `impact`

Goal: Analyze blast radius of changed files for plan review or risk assessment.

1. Run `get_impact_radius_tool` with the provided file list.
2. Identify high-risk files (many dependents, critical paths).
3. Return structured summary of what's affected.

**Output format:**
```
## Impact Analysis

### Changed Files
- [file] — [direct impact count] dependents

### High-Risk Areas
- [file] is imported by [N] files — changes here affect [list]

### Recommended Review Focus
- [file] — [reason it's risky]
```

#### Mode: `review`

Goal: Generate token-efficient review context for post-develop review.

1. Run `build_or_update_graph_tool` to capture new files.
2. Run `get_review_context_tool` (auto-detects changed files from git).
3. Extract the high-risk files and review guidance.
4. Return the review context summary (not full source — the LLM agent reads files).

**Output format:**
```
## Review Context

### Changed Files
- [file] — [change summary]

### High-Risk Files (review these first)
- [file] — [reason: N importers, critical path, etc.]

### Review Guidance
- [specific things to check based on graph analysis]
```

### Step 5: Return

Return the structured summary to the caller. Be concise — the caller will use this to inform design decisions, not as exhaustive documentation.

## Prerequisites

**Embeddings require `sentence-transformers` in the MCP server environment.** The `code-review-graph` plugin's `.mcp.json` must include it:

```json
{
  "mcpServers": {
    "code-review-graph": {
      "command": "uvx",
      "args": ["--with", "sentence-transformers", "code-review-graph", "serve"]
    }
  }
}
```

Without this, `embed_graph_tool` will fail and semantic search falls back to keyword matching. The skill still works — it uses `file_summary` and `query_graph_tool` as alternatives — but results are less accurate.

This is a one-time global setup. After adding `--with sentence-transformers`, restart Claude Code for the MCP server to pick it up.

## Notes

- Graph queries are fast (~10-50ms each) — the main cost is token consumption, not time
- Embeddings use `all-MiniLM-L6-v2` by default (~80MB model, downloaded once per project)
- After embedding, semantic search finds conceptually related code, not just keyword matches
- The agent typically makes 8-12 tool calls and returns a ~500-word summary
- If `embed_graph_tool` fails (missing dependency), the agent should log a warning and continue with keyword search — do not block the pipeline
