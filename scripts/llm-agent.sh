#!/bin/bash
# Run a local LLM agent with file access tools
# The LLM autonomously reads files and directories — Claude only receives the final answer
# Usage: llm-agent.sh "<task description>" [working_dir]
# Returns: agent's final answer to stdout
#
# Environment:
#   LLM_URL   - API base URL (default: http://127.0.0.1:1234)
#   LLM_MODEL - model identifier (default: qwen/qwen3.5-35b-a3b)

TASK="$1"
WORKDIR="${2:-$(pwd)}"
MODEL="${LLM_MODEL:-qwen/qwen3.5-35b-a3b}"
URL="${LLM_URL:-http://127.0.0.1:1234}"
LMS="${HOME}/.lmstudio/bin/lms"

# Check server
if ! curl -s --max-time 2 "$URL" > /dev/null 2>&1; then
  echo "LLM_UNAVAILABLE"
  exit 0
fi

# Empty task = availability check only
if [ -z "$TASK" ]; then
  echo "LLM_AVAILABLE"
  exit 0
fi

# Auto-load model with correct context length
if [ -x "$LMS" ]; then
  LOADED=$("$LMS" ps 2>/dev/null | grep -c "qwen3.5-35b-a3b")
  if [ "$LOADED" -eq 0 ]; then
    "$LMS" load "$MODEL" -c 65536 2>/dev/null
  else
    # Reload if context too small
    CTX=$("$LMS" ps 2>/dev/null | grep "qwen3.5-35b-a3b" | grep -oE '\b[0-9]{4,6}\b' | head -1)
    if [ -n "$CTX" ] && [ "$CTX" -lt 65536 ] 2>/dev/null; then
      "$LMS" unload "$MODEL" 2>/dev/null
      sleep 2
      "$LMS" load "$MODEL" -c 65536 2>/dev/null
    fi
  fi
fi

python3 - "$URL" "$MODEL" "$TASK" "$WORKDIR" <<'PYEOF'
import sys, json, urllib.request, os, subprocess

url = sys.argv[1]
model = sys.argv[2]
task = sys.argv[3]
workdir = sys.argv[4]

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": "Read the contents of a file. Use this to examine source code, configs, or any text file.",
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
            "description": "List files and directories at a path. Returns names with / suffix for directories.",
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
            "name": "git_log",
            "description": "Show git commit history. Use to understand recent changes, find when a file was modified, or trace who changed what.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "File or directory to show history for (optional, empty for all)"},
                    "count": {"type": "integer", "description": "Number of commits to show (default: 10)"}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "git_diff",
            "description": "Show changes in the working directory or between commits. Use to review what was modified.",
            "parameters": {
                "type": "object",
                "properties": {
                    "ref": {"type": "string", "description": "Git ref to diff against (e.g. 'HEAD~3', 'main', a commit hash). Default: staged + unstaged changes."}
                }
            }
        }
    }
]

def execute_tool(name, args):
    try:
        if name == "read_file":
            filepath = os.path.join(workdir, args["path"])
            if not os.path.isfile(filepath):
                return f"Error: File not found: {args['path']}"
            with open(filepath) as f:
                content = f.read()
            # Limit file size to prevent context overflow
            max_size = 8000 if total_tool_content > 10000 else 15000
            if len(content) > max_size:
                content = content[:max_size] + f"\n... (truncated at {max_size} chars, {len(content)} total)"
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
            # Return stat summary only — agent should use read_file for specific files
            cmd = ["git", "-C", workdir, "diff", "--stat"]
            if ref:
                cmd.append(ref)
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            output = result.stdout
            if not output:
                return "No changes found"
            return f"{output}\nTo see the actual changes, use read_file on the files listed above."

    except Exception as e:
        return f"Error: {e}"

messages = [
    {"role": "user", "content": f"/no_think\n{task}\n\nYou have tools to read files, search code, and check git history. Use them to investigate, then give a concise final answer. Be efficient — don't read files you don't need. Working directory: {workdir}"}
]

MAX_ITERATIONS = 25
total_tool_content = 0

for i in range(MAX_ITERATIONS):
    # Switch off thinking when context is large to prevent overflow
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
        resp = json.loads(urllib.request.urlopen(req, timeout=120).read())
    except Exception as e:
        print(f"LLM_ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    choice = resp["choices"][0]
    msg = choice["message"]
    messages.append(msg)

    # Check if model wants to call tools
    tool_calls = msg.get("tool_calls", [])
    if not tool_calls:
        # No tool calls — this is the final answer
        content = msg.get("content", "")
        reasoning = msg.get("reasoning_content", "")
        if content.strip():
            print(content)
        elif reasoning.strip():
            # Thinking overflow — extract useful content from reasoning
            print(reasoning)
        else:
            print("LLM_ERROR: empty response")
        break

    # Execute tool calls and add results
    for tc in tool_calls:
        fn_name = tc["function"]["name"]
        fn_args = json.loads(tc["function"]["args"] if "args" in tc["function"] else tc["function"].get("arguments", "{}"))
        result = execute_tool(fn_name, fn_args)
        total_tool_content += len(result)
        messages.append({
            "role": "tool",
            "tool_call_id": tc["id"],
            "content": result
        })
else:
    print("LLM_ERROR: max iterations reached", file=sys.stderr)
    sys.exit(1)
PYEOF
