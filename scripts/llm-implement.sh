#!/bin/bash
# Run a local LLM implementation agent with file read/write tools
# Extends llm-agent.sh with write_file, pre-loaded context, and STATUS parsing
# Usage: llm-implement.sh <task-file> <working-dir> <allowed-files> [ref-file1] [ref-file2] ...
# Returns: JSON status to stdout (matching codex-status-schema.json)
#
# Arguments:
#   task-file     - Path to a text file containing the task description
#   working-dir   - Project root directory
#   allowed-files - Comma-separated list of file paths write_file may create/modify
#   ref-file*     - Reference files to pre-load into system prompt context
#
# Environment:
#   LLM_URL            - API base URL (default from llm-config.sh)
#   LLM_MODEL          - model identifier (default from llm-config.sh)
#   LLM_CONTEXT_LENGTH - context window size (default from llm-config.sh)

source "$(dirname "$0")/llm-config.sh"

TASK_FILE="$1"
WORKDIR="$2"
ALLOWED_FILES="$3"
shift 3
REF_FILES=("$@")

if [ -z "$TASK_FILE" ] || [ -z "$WORKDIR" ] || [ -z "$ALLOWED_FILES" ]; then
  echo '{"status":"BLOCKED","severity":"major","summary":"Missing required arguments","files_changed":[],"exports_added":[],"dependencies_added":[],"concerns":"Usage: llm-implement.sh <task-file> <working-dir> <allowed-files> [ref-files...]","notes":""}'
  exit 0
fi

if [ ! -f "$TASK_FILE" ]; then
  echo '{"status":"BLOCKED","severity":"major","summary":"Task file not found","files_changed":[],"exports_added":[],"dependencies_added":[],"concerns":"Task file not found: '"$TASK_FILE"'","notes":""}'
  exit 0
fi

# Check server
if ! curl -s --max-time 2 "$LLM_URL" > /dev/null 2>&1; then
  echo '{"status":"BLOCKED","severity":"major","summary":"LLM unavailable","files_changed":[],"exports_added":[],"dependencies_added":[],"concerns":"LM Studio not running on '"$LLM_URL"'","notes":""}'
  exit 0
fi

# Auto-load model
llm_ensure_loaded

# Write ref file paths to a temp file for Python to read
REF_LIST_FILE=$(mktemp)
for ref in "${REF_FILES[@]}"; do
  echo "$ref" >> "$REF_LIST_FILE"
done

python3 - "$LLM_URL" "$LLM_MODEL" "$WORKDIR" "$ALLOWED_FILES" "$TASK_FILE" "$REF_LIST_FILE" <<'PYEOF'
import sys, json, urllib.request, os, subprocess, re

url = sys.argv[1]
model = sys.argv[2]
workdir = sys.argv[3]
allowed_files = set(sys.argv[4].split(","))
task_file = sys.argv[5]
ref_list_file = sys.argv[6]

# Read task description
with open(task_file) as f:
    TASK_CONTENT = f.read()

# Read shared state (if exists)
shared_state_path = os.path.join(workdir, ".shared-state.md")
SHARED_STATE = ""
if os.path.isfile(shared_state_path):
    with open(shared_state_path) as f:
        SHARED_STATE = f.read()[:4000]

# Read reference files (max 20K chars total)
REF_CONTENT = ""
ref_total = 0
ref_max = 20000
ref_per_file = 8000
with open(ref_list_file) as f:
    ref_paths = [line.strip() for line in f if line.strip()]
for ref_path in ref_paths:
    if os.path.isfile(ref_path):
        with open(ref_path) as f:
            content = f.read()[:ref_per_file]
        if ref_total + len(content) > ref_max:
            break
        REF_CONTENT += f"\n--- REFERENCE: {os.path.basename(ref_path)} ---\n{content}\n--- END REFERENCE ---\n"
        ref_total += len(content)
os.unlink(ref_list_file)

SYSTEM_PROMPT = """You are a senior developer implementing code for a project. Read the reference files and shared state to understand the architecture and conventions.

## Rules
- Follow existing patterns exactly as shown in the reference files
- Use named exports only (no default exports)
- Follow TypeScript best practices with proper typing
- Respect architecture module boundaries
- Use the write_file tool to create/modify files
- Use read_file, list_dir, search_code to explore the codebase when needed

## Output Format
After completing your work, you MUST end with a STATUS block in this exact format:

--- STATUS ---
status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
severity: none | minor | major
files_changed: ["path/to/file1.ts", "path/to/file2.ts"]
exports_added: ["ExportName1", "ExportName2"]
concerns: none | description of concerns
notes: optional notes for orchestrator
--- END STATUS ---

## Reference Files (study these patterns)
""" + REF_CONTENT + """

## Current Shared State
""" + (SHARED_STATE or "(empty)") + """

## Task
""" + TASK_CONTENT

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": "Read the contents of a file.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "Relative path from project root"}
                },
                "required": ["path"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "list_dir",
            "description": "List files and directories at a path.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "Relative path from project root (use '.' for root)"}
                },
                "required": ["path"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "search_code",
            "description": "Search for a pattern in files. Returns matching lines with file paths.",
            "parameters": {
                "type": "object",
                "properties": {
                    "pattern": {"type": "string", "description": "Search pattern (regex supported)"},
                    "path": {"type": "string", "description": "Directory to search in (default: '.')"}
                },
                "required": ["pattern"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "write_file",
            "description": "Write content to a file. Only allowed for files in the task scope.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "Relative path from project root"},
                    "content": {"type": "string", "description": "Full file content to write"}
                },
                "required": ["path", "content"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "git_log",
            "description": "Show git commit history.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "File or directory to show history for"},
                    "count": {"type": "integer", "description": "Number of commits to show (default: 10)"}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "git_diff",
            "description": "Show changes in the working directory or between commits.",
            "parameters": {
                "type": "object",
                "properties": {
                    "ref": {"type": "string", "description": "Git ref to diff against"}
                }
            }
        }
    }
]

files_written = []

def execute_tool(name, args):
    global files_written
    try:
        if name == "read_file":
            filepath = os.path.join(workdir, args["path"])
            if not os.path.isfile(filepath):
                return f"Error: File not found: {args['path']}"
            with open(filepath) as f:
                content = f.read()
            max_size = 8000 if total_tool_content > 10000 else 15000
            if len(content) > max_size:
                content = content[:max_size] + f"\n... (truncated at {max_size} chars)"
            return content

        elif name == "list_dir":
            dirpath = os.path.join(workdir, args["path"])
            if not os.path.isdir(dirpath):
                return f"Error: Directory not found: {args['path']}"
            entries = []
            for entry in sorted(os.listdir(dirpath)):
                full = os.path.join(dirpath, entry)
                if entry.startswith('.'):
                    continue
                entries.append(f"{entry}/" if os.path.isdir(full) else entry)
            return "\n".join(entries[:100])

        elif name == "search_code":
            search_path = os.path.join(workdir, args.get("path", "."))
            result = subprocess.run(
                ["grep", "-rn", "--include=*.ts", "--include=*.tsx", "--include=*.md",
                 args["pattern"], search_path],
                capture_output=True, text=True, timeout=10
            )
            output = result.stdout
            if len(output) > 10000:
                output = output[:10000] + "\n... (truncated)"
            return output or "No matches found"

        elif name == "write_file":
            rel_path = args["path"]
            # Path restriction: no absolute paths, no traversal
            if rel_path.startswith("/") or ".." in rel_path:
                return f"ERROR: path must be relative and cannot contain '..'. Got: {rel_path}"
            # Scope restriction: check allowed list
            if rel_path not in allowed_files:
                return f"ERROR: path not in task scope. Allowed: {', '.join(allowed_files)}. If this file is necessary, report NEEDS_CONTEXT with the path in your concerns."
            filepath = os.path.join(workdir, rel_path)
            # Create parent directories
            os.makedirs(os.path.dirname(filepath), exist_ok=True)
            # Warn on overwrite
            if os.path.exists(filepath):
                print(f"WARN: overwriting existing file {rel_path}", file=sys.stderr)
            # Atomic write: temp file + rename
            tmp_path = filepath + ".tmp"
            with open(tmp_path, "w") as f:
                f.write(args["content"])
            os.rename(tmp_path, filepath)
            files_written.append(rel_path)
            return f"OK: wrote {len(args['content'])} chars to {rel_path}"

        elif name == "git_log":
            cmd = ["git", "-C", workdir, "log", "--oneline",
                   f"-{args.get('count', 10)}"]
            path = args.get("path", "")
            if path:
                cmd += ["--", path]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            return result.stdout or "No git history found"

        elif name == "git_diff":
            ref = args.get("ref", "")
            cmd = ["git", "-C", workdir, "diff", "--stat"]
            if ref:
                cmd.append(ref)
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            return result.stdout or "No changes found"

    except Exception as e:
        return f"Error: {e}"

messages = [
    {"role": "system", "content": SYSTEM_PROMPT},
    {"role": "user", "content": "/no_think\nImplement the task described above. Use the reference files as patterns. Use write_file to create the implementation files. End with the STATUS block."}
]

MAX_ITERATIONS = 25
total_tool_content = 0

for i in range(MAX_ITERATIONS):
    use_think = total_tool_content < 20000

    data = json.dumps({
        "model": model,
        "max_tokens": 32768,
        "messages": messages,
        "tools": TOOLS,
        "temperature": 0.6 if use_think else 0.3,
        "top_p": 0.95
    }).encode()

    req = urllib.request.Request(
        f"{url}/v1/chat/completions", data=data,
        headers={"Content-Type": "application/json"}
    )

    try:
        resp = json.loads(urllib.request.urlopen(req, timeout=180).read())
    except Exception as e:
        print(json.dumps({
            "status": "BLOCKED", "severity": "major",
            "summary": f"LLM API error: {e}",
            "files_changed": files_written, "exports_added": [],
            "dependencies_added": [], "concerns": str(e), "notes": ""
        }))
        sys.exit(0)

    choice = resp["choices"][0]
    msg = choice["message"]
    messages.append(msg)

    tool_calls = msg.get("tool_calls", [])
    if not tool_calls:
        # Final answer — parse STATUS block
        content = msg.get("content", "") or msg.get("reasoning_content", "")
        status_match = re.search(r'--- STATUS ---\s*\n(.*?)\n--- END STATUS ---', content, re.DOTALL)
        if status_match:
            status_text = status_match.group(1)
            # Parse key-value pairs
            def extract(key, default=""):
                m = re.search(rf'^{key}:\s*(.+)$', status_text, re.MULTILINE)
                return m.group(1).strip() if m else default

            status_val = extract("status", "DONE_WITH_CONCERNS")
            severity_val = extract("severity", "minor")
            concerns_val = extract("concerns", "none")
            notes_val = extract("notes", "")

            # Parse array fields
            fc_match = re.search(r'files_changed:\s*\[([^\]]*)\]', status_text)
            fc = [f.strip().strip('"').strip("'") for f in fc_match.group(1).split(",") if f.strip()] if fc_match else files_written

            ea_match = re.search(r'exports_added:\s*\[([^\]]*)\]', status_text)
            ea = [e.strip().strip('"').strip("'") for e in ea_match.group(1).split(",") if e.strip()] if ea_match else []

            print(json.dumps({
                "status": status_val,
                "severity": severity_val,
                "summary": f"Implemented task with {len(files_written)} file(s) written",
                "files_changed": fc if fc else files_written,
                "exports_added": ea,
                "dependencies_added": [],
                "concerns": concerns_val if concerns_val != "none" else "",
                "notes": notes_val
            }))
        else:
            # No STATUS block — treat as DONE_WITH_CONCERNS
            print(json.dumps({
                "status": "DONE_WITH_CONCERNS",
                "severity": "minor",
                "summary": f"Completed but no STATUS block found. {len(files_written)} file(s) written.",
                "files_changed": files_written,
                "exports_added": [],
                "dependencies_added": [],
                "concerns": "LLM did not produce a STATUS block. Files were written but status is uncertain.",
                "notes": content[:500] if content else ""
            }))
        break

    # Execute tool calls
    for tc in tool_calls:
        fn_name = tc["function"]["name"]
        fn_args = json.loads(tc["function"].get("args") or tc["function"].get("arguments", "{}"))
        result = execute_tool(fn_name, fn_args)
        total_tool_content += len(result)
        messages.append({
            "role": "tool",
            "tool_call_id": tc["id"],
            "content": result
        })
else:
    print(json.dumps({
        "status": "DONE_WITH_CONCERNS", "severity": "minor",
        "summary": f"Max iterations reached. {len(files_written)} file(s) written.",
        "files_changed": files_written, "exports_added": [],
        "dependencies_added": [],
        "concerns": "Max iterations (25) reached before LLM produced final answer",
        "notes": ""
    }))
PYEOF
